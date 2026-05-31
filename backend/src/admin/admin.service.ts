import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, ReportStatus, UserRole } from '@prisma/client';

import { AuthenticatedUser } from '../auth/types/authenticated-user';
import { PrismaService } from '../prisma/prisma.service';
import { AdminReportQueryDto } from './dto/admin-report-query.dto';
import { BlockUserDto } from './dto/block-user.dto';
import { ReportActionDto } from './dto/report-action.dto';
import { UpdateReportStatusDto } from './dto/update-report-status.dto';
import { UserQueryDto } from './dto/user-query.dto';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  async getDashboardStats() {
    const [
      totalReports,
      pendingReports,
      queuedReports,
      acceptedReports,
      inProgressReports,
      resolvedReports,
      rejectedReports,
      suspectedSpamReports,
      flaggedReports,
      blockedUsers,
    ] = await Promise.all([
      this.prisma.report.count(),
      this.prisma.report.count({ where: { status: ReportStatus.pending } }),
      this.prisma.report.count({ where: { status: ReportStatus.queued } }),
      this.prisma.report.count({ where: { status: ReportStatus.accepted } }),
      this.prisma.report.count({ where: { status: ReportStatus.in_progress } }),
      this.prisma.report.count({ where: { status: ReportStatus.resolved } }),
      this.prisma.report.count({ where: { status: ReportStatus.rejected } }),
      this.prisma.report.count({ where: { isSuspectedSpam: true } }),
      this.prisma.reportFlag.count(),
      this.prisma.profile.count({ where: { isBlocked: true } }),
    ]);

    return {
      total_reports: totalReports,
      pending_reports: pendingReports,
      queued_reports: queuedReports,
      accepted_reports: acceptedReports,
      in_progress_reports: inProgressReports,
      resolved_reports: resolvedReports,
      rejected_reports: rejectedReports,
      suspected_spam_reports: suspectedSpamReports,
      flagged_reports: flaggedReports,
      blocked_users: blockedUsers,
    };
  }

  async getReports(query: AdminReportQueryDto) {
    const { page, limit, skip, take } = this.getPagination(query);
    const where = this.buildReportWhere(query);

    const [reports, total] = await Promise.all([
      this.prisma.report.findMany({
        where,
        include: this.reportInclude(),
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.report.count({ where }),
    ]);

    return {
      data: reports.map((report) => this.mapReport(report)),
      meta: { page, limit, total },
    };
  }

  async getSuspectedSpamReports(query: AdminReportQueryDto) {
    return this.getReports({ ...query, suspectedSpam: 'true' });
  }

  async getFlaggedReports(query: AdminReportQueryDto) {
    return this.getReports({ ...query, flagged: 'true' });
  }

  async getReport(reportId: string) {
    const report = await this.prisma.report.findUnique({
      where: { id: reportId },
      include: {
        ...this.reportInclude(),
        statusUpdates: {
          include: { updater: { select: { id: true, fullName: true, role: true } } },
          orderBy: { createdAt: 'desc' },
        },
        comments: {
          include: { user: { select: { id: true, fullName: true } } },
          orderBy: { createdAt: 'desc' },
        },
        flags: {
          include: { user: { select: { id: true, fullName: true } } },
          orderBy: { createdAt: 'desc' },
        },
      },
    });

    if (!report) {
      throw new NotFoundException('Laporan tidak ditemukan');
    }

    return {
      ...this.mapReport(report),
      status_updates: report.statusUpdates.map((update) => ({
        id: update.id,
        status: update.status,
        note: update.note,
        updated_by: update.updatedBy,
        updater_name: update.updater?.fullName ?? null,
        updater_role: update.updater?.role ?? null,
        created_at: update.createdAt,
      })),
      comments: report.comments.map((comment) => ({
        id: comment.id,
        user_id: comment.userId,
        author_name: comment.user.fullName ?? 'Warga',
        body: comment.body,
        created_at: comment.createdAt,
      })),
      flags: report.flags.map((flag) => ({
        id: flag.id,
        user_id: flag.userId,
        reporter_name: flag.user.fullName ?? 'Warga',
        reason: flag.reason,
        created_at: flag.createdAt,
      })),
    };
  }

  updateReportStatus(
    user: AuthenticatedUser,
    reportId: string,
    dto: UpdateReportStatusDto,
  ) {
    const status = this.parseReportStatus(dto.status);
    return this.setReportStatus(user, reportId, status, dto.note);
  }

  acceptReport(user: AuthenticatedUser, reportId: string, dto: ReportActionDto) {
    return this.setReportStatus(
      user,
      reportId,
      ReportStatus.accepted,
      dto.note ?? 'Laporan diterima oleh petugas.',
    );
  }

  rejectReport(user: AuthenticatedUser, reportId: string, dto: ReportActionDto) {
    return this.setReportStatus(
      user,
      reportId,
      ReportStatus.rejected,
      dto.note ?? 'Laporan ditolak oleh petugas.',
    );
  }

  async getUsers(query: UserQueryDto) {
    const { page, limit, skip, take } = this.getPagination(query);
    const where = this.buildUserWhere(query);

    const [users, total] = await Promise.all([
      this.prisma.profile.findMany({
        where,
        include: {
          _count: { select: { reports: true, flags: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.profile.count({ where }),
    ]);

    return {
      data: users.map((user) => ({
        id: user.id,
        full_name: user.fullName,
        role: user.role,
        is_blocked: user.isBlocked,
        report_count: user._count.reports,
        flag_count: user._count.flags,
        created_at: user.createdAt,
      })),
      meta: { page, limit, total },
    };
  }

  async blockUser(
    staff: AuthenticatedUser,
    userId: string,
    dto: BlockUserDto,
  ) {
    if (staff.id === userId) {
      throw new BadRequestException('Tidak dapat memblokir akun sendiri');
    }

    const user = await this.prisma.profile.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User tidak ditemukan');
    }

    const reason = dto.reason?.trim() || 'Diblokir oleh petugas.';

    await this.prisma.$transaction([
      this.prisma.profile.update({
        where: { id: userId },
        data: { isBlocked: true },
      }),
      this.prisma.userBlock.create({
        data: {
          userId,
          blockedBy: staff.id,
          reason,
        },
      }),
    ]);

    return { message: 'User berhasil diblokir.' };
  }

  async unblockUser(userId: string) {
    const user = await this.prisma.profile.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User tidak ditemukan');
    }

    await this.prisma.profile.update({
      where: { id: userId },
      data: { isBlocked: false },
    });

    return { message: 'User berhasil dibuka blokirnya.' };
  }

  private async setReportStatus(
    user: AuthenticatedUser,
    reportId: string,
    status: ReportStatus,
    note?: string,
  ) {
    const report = await this.prisma.report.findUnique({
      where: { id: reportId },
      select: { id: true },
    });

    if (!report) {
      throw new NotFoundException('Laporan tidak ditemukan');
    }

    const updatedReport = await this.prisma.report.update({
      where: { id: reportId },
      data: {
        status,
        isSuspectedSpam: status === ReportStatus.suspected_spam,
        statusUpdates: {
          create: {
            status,
            note: note?.trim() || this.defaultStatusNote(status),
            updatedBy: user.id,
          },
        },
      },
      include: this.reportInclude(),
    });

    return this.mapReport(updatedReport);
  }

  private buildReportWhere(query: AdminReportQueryDto): Prisma.ReportWhereInput {
    const where: Prisma.ReportWhereInput = {};

    if (query.status) {
      where.status = this.parseReportStatus(query.status);
    }

    if (query.categoryId) {
      const categoryId = Number(query.categoryId);
      if (!Number.isInteger(categoryId) || categoryId < 1) {
        throw new BadRequestException('Kategori tidak valid');
      }
      where.categoryId = BigInt(categoryId);
    }

    if (query.suspectedSpam === 'true') {
      where.isSuspectedSpam = true;
    } else if (query.suspectedSpam === 'false') {
      where.isSuspectedSpam = false;
    }

    if (query.flagged === 'true') {
      where.flags = { some: {} };
    }

    const search = query.search?.trim();
    if (search) {
      where.OR = [
        { description: { contains: search, mode: 'insensitive' } },
        { category: { name: { contains: search, mode: 'insensitive' } } },
      ];
    }

    return where;
  }

  private buildUserWhere(query: UserQueryDto): Prisma.ProfileWhereInput {
    const where: Prisma.ProfileWhereInput = {};

    if (query.role) {
      where.role = this.parseUserRole(query.role);
    }

    if (query.blocked === 'true') {
      where.isBlocked = true;
    } else if (query.blocked === 'false') {
      where.isBlocked = false;
    }

    const search = query.search?.trim();
    if (search) {
      where.fullName = { contains: search, mode: 'insensitive' };
    }

    return where;
  }

  private parseReportStatus(status?: string): ReportStatus {
    const normalized = status?.trim() as ReportStatus | undefined;
    if (!normalized || !Object.values(ReportStatus).includes(normalized)) {
      throw new BadRequestException('Status laporan tidak valid');
    }

    return normalized;
  }

  private parseUserRole(role?: string): UserRole {
    const normalized = role?.trim() as UserRole | undefined;
    if (!normalized || !Object.values(UserRole).includes(normalized)) {
      throw new BadRequestException('Role user tidak valid');
    }

    return normalized;
  }

  private getPagination(query: { page?: string; limit?: string }) {
    const page = Math.max(Number(query.page) || 1, 1);
    const limit = Math.min(Math.max(Number(query.limit) || 20, 1), 100);

    return {
      page,
      limit,
      skip: (page - 1) * limit,
      take: limit,
    };
  }

  private reportInclude() {
    return {
      category: true,
      user: { select: { id: true, fullName: true, role: true, isBlocked: true } },
      _count: { select: { comments: true, upvotes: true, flags: true } },
    } satisfies Prisma.ReportInclude;
  }

  private mapReport(report: {
    id: string;
    userId: string;
    categoryId: bigint;
    category: { name: string };
    user: { id: string; fullName: string | null; role: UserRole; isBlocked: boolean };
    description: string;
    photoUrl: string;
    latitude: number;
    longitude: number;
    status: ReportStatus;
    isSuspectedSpam: boolean;
    submittedOutsideOfficeHours: boolean;
    createdAt: Date;
    updatedAt: Date;
    _count: { comments: number; upvotes: number; flags: number };
  }) {
    return {
      id: report.id,
      user_id: report.userId,
      reporter_name: report.user.fullName ?? 'Warga',
      reporter_role: report.user.role,
      reporter_is_blocked: report.user.isBlocked,
      category_id: Number(report.categoryId),
      category_name: report.category.name,
      description: report.description,
      photo_url: report.photoUrl,
      latitude: report.latitude,
      longitude: report.longitude,
      status: report.status,
      is_suspected_spam: report.isSuspectedSpam,
      submitted_outside_office_hours: report.submittedOutsideOfficeHours,
      comment_count: report._count.comments,
      upvote_count: report._count.upvotes,
      flag_count: report._count.flags,
      created_at: report.createdAt,
      updated_at: report.updatedAt,
    };
  }

  private defaultStatusNote(status: ReportStatus) {
    switch (status) {
      case ReportStatus.accepted:
        return 'Laporan diterima.';
      case ReportStatus.rejected:
        return 'Laporan ditolak.';
      case ReportStatus.in_progress:
        return 'Laporan sedang ditindaklanjuti.';
      case ReportStatus.resolved:
        return 'Laporan selesai ditangani.';
      case ReportStatus.suspected_spam:
        return 'Laporan ditandai sebagai dugaan spam.';
      case ReportStatus.queued:
        return 'Laporan masuk antrean.';
      default:
        return 'Status laporan diperbarui.';
    }
  }
}
