import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ReportStatus } from '@prisma/client';

import { AuthenticatedUser } from '../auth/types/authenticated-user';
import { isInIndonesia } from '../common/geo/indonesia-bounds';
import { PrismaService } from '../prisma/prisma.service';
import { CreateReportCommentDto } from './dto/create-report-comment.dto';
import { CreateReportDto } from './dto/create-report.dto';
import { FlagReportDto } from './dto/flag-report.dto';
import { NearbyReportsQueryDto } from './dto/nearby-reports-query.dto';

@Injectable()
export class CitizenService {
  constructor(private readonly prisma: PrismaService) {}

  getMe(user: AuthenticatedUser) {
    return user;
  }

  async getMyReports(user: AuthenticatedUser) {
    const reports = await this.prisma.report.findMany({
      where: { userId: user.id },
      include: { category: true },
      orderBy: { createdAt: 'desc' },
    });

    return reports.map((report) => ({
      id: report.id,
      user_id: report.userId,
      category_id: Number(report.categoryId),
      category_name: report.category.name,
      description: report.description,
      photo_url: report.photoUrl,
      latitude: report.latitude,
      longitude: report.longitude,
      status: report.status,
      is_suspected_spam: report.isSuspectedSpam,
      submitted_outside_office_hours: report.submittedOutsideOfficeHours,
      created_at: report.createdAt,
      updated_at: report.updatedAt,
    }));
  }

  async getCommunityReports(user: AuthenticatedUser) {
    const reports = await this.prisma.report.findMany({
      where: {
        isSuspectedSpam: false,
        status: { not: ReportStatus.rejected },
      },
      include: {
        category: true,
        _count: { select: { comments: true, upvotes: true } },
        upvotes: { where: { userId: user.id }, select: { id: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    return reports.map((report) => this.mapPublicReport(report));
  }

  async getNearbyReports(user: AuthenticatedUser, query: NearbyReportsQueryDto) {
    const latitude = Number(query.latitude);
    const longitude = Number(query.longitude);
    const radiusKm = Math.min(Math.max(Number(query.radiusKm) || 5, 1), 25);

    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      throw new BadRequestException('Koordinat pencarian tidak valid');
    }

    if (!isInIndonesia(latitude, longitude)) {
      throw new BadRequestException('Area pencarian harus berada di Indonesia');
    }

    const latitudeDelta = radiusKm / 111;
    const longitudeDelta =
      radiusKm / (111 * Math.max(Math.cos((latitude * Math.PI) / 180), 0.2));

    const reports = await this.prisma.report.findMany({
      where: {
        isSuspectedSpam: false,
        status: { not: ReportStatus.rejected },
        latitude: {
          gte: latitude - latitudeDelta,
          lte: latitude + latitudeDelta,
        },
        longitude: {
          gte: longitude - longitudeDelta,
          lte: longitude + longitudeDelta,
        },
      },
      include: {
        category: true,
        _count: { select: { comments: true, upvotes: true } },
        upvotes: { where: { userId: user.id }, select: { id: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });

    return reports.map((report) => this.mapPublicReport(report));
  }

  async createReport(user: AuthenticatedUser, dto: CreateReportDto) {
    this.validateCreateReport(dto);

    const submittedOutsideOfficeHours = this.isOutsideOfficeHours();
    const suspectedSpam = this.isSuspectedSpam(dto.description);
    const status = suspectedSpam
      ? ReportStatus.suspected_spam
      : submittedOutsideOfficeHours
        ? ReportStatus.queued
        : ReportStatus.pending;

    const report = await this.prisma.report.create({
      data: {
        userId: user.id,
        categoryId: BigInt(dto.categoryId),
        description: dto.description.trim(),
        photoUrl: dto.photoUrl,
        latitude: dto.latitude,
        longitude: dto.longitude,
        status,
        isSuspectedSpam: suspectedSpam,
        submittedOutsideOfficeHours,
        review: suspectedSpam
          ? {
              create: {
                spamScore: 0.75,
                spamReason: 'Deskripsi terdeteksi terlalu pendek atau repetitif.',
              },
            }
          : undefined,
        statusUpdates: {
          create: {
            status,
            note: suspectedSpam
              ? 'Laporan masuk ke inbox dugaan spam.'
              : submittedOutsideOfficeHours
                ? 'Laporan diterima di luar jam layanan dan masuk antrean.'
                : 'Laporan berhasil diterima.',
          },
        },
      },
      include: { category: true },
    });

    return {
      id: report.id,
      user_id: report.userId,
      category_id: Number(report.categoryId),
      category_name: report.category.name,
      description: report.description,
      photo_url: report.photoUrl,
      latitude: report.latitude,
      longitude: report.longitude,
      status: report.status,
      is_suspected_spam: report.isSuspectedSpam,
      submitted_outside_office_hours: report.submittedOutsideOfficeHours,
      created_at: report.createdAt,
      updated_at: report.updatedAt,
    };
  }

  async getReportComments(reportId: string) {
    await this.ensurePublicReportExists(reportId);

    const comments = await this.prisma.reportComment.findMany({
      where: { reportId },
      include: { user: { select: { fullName: true } } },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    return comments.map((comment) => ({
      id: comment.id,
      report_id: comment.reportId,
      body: comment.body,
      author_name: comment.user.fullName ?? 'Warga',
      created_at: comment.createdAt,
    }));
  }

  async addReportComment(
    user: AuthenticatedUser,
    reportId: string,
    dto: CreateReportCommentDto,
  ) {
    await this.ensurePublicReportExists(reportId);

    const body = dto.body?.trim();
    if (!body || body.length < 3) {
      throw new BadRequestException('Komentar terlalu pendek');
    }

    if (body.length > 280) {
      throw new BadRequestException('Komentar maksimal 280 karakter');
    }

    const comment = await this.prisma.reportComment.create({
      data: {
        reportId,
        userId: user.id,
        body,
      },
      include: { user: { select: { fullName: true } } },
    });

    return {
      id: comment.id,
      report_id: comment.reportId,
      body: comment.body,
      author_name: comment.user.fullName ?? 'Warga',
      created_at: comment.createdAt,
    };
  }

  async toggleReportUpvote(user: AuthenticatedUser, reportId: string) {
    await this.ensurePublicReportExists(reportId);

    const existing = await this.prisma.reportUpvote.findUnique({
      where: { reportId_userId: { reportId, userId: user.id } },
    });

    if (existing) {
      await this.prisma.reportUpvote.delete({ where: { id: existing.id } });
    } else {
      await this.prisma.reportUpvote.create({
        data: { reportId, userId: user.id },
      });
    }

    const upvoteCount = await this.prisma.reportUpvote.count({
      where: { reportId },
    });

    return {
      upvote_count: upvoteCount,
      has_upvoted: !existing,
    };
  }

  async flagReport(
    user: AuthenticatedUser,
    reportId: string,
    dto: FlagReportDto,
  ) {
    await this.ensurePublicReportExists(reportId);

    const reason = dto.reason?.trim() || 'Perlu ditinjau';
    if (reason.length > 180) {
      throw new BadRequestException('Alasan laporan maksimal 180 karakter');
    }

    await this.prisma.reportFlag.upsert({
      where: { reportId_userId: { reportId, userId: user.id } },
      create: { reportId, userId: user.id, reason },
      update: { reason },
    });

    return { message: 'Laporan ditandai untuk ditinjau admin.' };
  }

  private async ensurePublicReportExists(reportId: string) {
    const report = await this.prisma.report.findFirst({
      where: {
        id: reportId,
        isSuspectedSpam: false,
        status: { not: ReportStatus.rejected },
      },
      select: { id: true },
    });

    if (!report) {
      throw new NotFoundException('Laporan tidak ditemukan');
    }
  }

  private mapPublicReport(report: {
    id: string;
    categoryId: bigint;
    category: { name: string };
    description: string;
    photoUrl: string;
    latitude: number;
    longitude: number;
    status: ReportStatus;
    isSuspectedSpam: boolean;
    submittedOutsideOfficeHours: boolean;
    createdAt: Date;
    updatedAt: Date;
    _count: { comments: number; upvotes: number };
    upvotes: { id: string }[];
  }) {
    return {
      id: report.id,
      user_id: '',
      category_id: Number(report.categoryId),
      category_name: report.category.name,
      description: report.description,
      photo_url: report.photoUrl,
      latitude: report.latitude,
      longitude: report.longitude,
      status: report.status,
      is_suspected_spam: report.isSuspectedSpam,
      submitted_outside_office_hours: report.submittedOutsideOfficeHours,
      upvote_count: report._count.upvotes,
      comment_count: report._count.comments,
      has_upvoted: report.upvotes.length > 0,
      created_at: report.createdAt,
      updated_at: report.updatedAt,
    };
  }

  private validateCreateReport(dto: CreateReportDto) {
    if (!dto.categoryId || dto.categoryId < 1) {
      throw new BadRequestException('Kategori laporan wajib dipilih');
    }

    if (!dto.description?.trim() || dto.description.trim().length < 12) {
      throw new BadRequestException('Deskripsi laporan terlalu pendek');
    }

    if (!dto.photoUrl?.trim()) {
      throw new BadRequestException('Foto laporan wajib dilampirkan');
    }

    if (!Number.isFinite(dto.latitude) || !Number.isFinite(dto.longitude)) {
      throw new BadRequestException('Koordinat laporan tidak valid');
    }

    if (!isInIndonesia(dto.latitude, dto.longitude)) {
      throw new BadRequestException(
        'Lokasi laporan harus berada di wilayah Indonesia',
      );
    }
  }

  private isOutsideOfficeHours() {
    const now = new Date();
    const jakartaHour = (now.getUTCHours() + 7) % 24;

    return jakartaHour < 9 || jakartaHour >= 17;
  }

  private isSuspectedSpam(description: string) {
    const text = description.trim().toLowerCase();
    const words = text.split(/\s+/);
    const uniqueWords = new Set(words);

    return text.length < 16 || (words.length >= 6 && uniqueWords.size <= 2);
  }
}
