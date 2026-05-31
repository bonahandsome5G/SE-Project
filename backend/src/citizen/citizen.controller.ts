import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { SupabaseJwtGuard } from '../auth/guards/supabase-jwt.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';
import { CitizenService } from './citizen.service';
import { CreateReportCommentDto } from './dto/create-report-comment.dto';
import { CreateReportDto } from './dto/create-report.dto';
import { FlagReportDto } from './dto/flag-report.dto';
import { NearbyReportsQueryDto } from './dto/nearby-reports-query.dto';

@Controller('citizen')
@UseGuards(SupabaseJwtGuard, RolesGuard)
@Roles(UserRole.citizen)
export class CitizenController {
  constructor(private readonly citizenService: CitizenService) {}

  @Get()
  index(@CurrentUser() user: AuthenticatedUser) {
    return {
      module: 'citizen',
      user,
      routes: ['reports', 'report-status'],
    };
  }

  @Get('me')
  getMe(@CurrentUser() user: AuthenticatedUser) {
    return this.citizenService.getMe(user);
  }

  @Get('reports')
  getMyReports(@CurrentUser() user: AuthenticatedUser) {
    return this.citizenService.getMyReports(user);
  }

  @Get('community-reports')
  getCommunityReports(@CurrentUser() user: AuthenticatedUser) {
    return this.citizenService.getCommunityReports(user);
  }

  @Get('reports/nearby')
  getNearbyReports(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: NearbyReportsQueryDto,
  ) {
    return this.citizenService.getNearbyReports(user, query);
  }

  @Post('reports')
  createReport(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateReportDto,
  ) {
    return this.citizenService.createReport(user, dto);
  }

  @Get('reports/:reportId/comments')
  getReportComments(@Param('reportId') reportId: string) {
    return this.citizenService.getReportComments(reportId);
  }

  @Post('reports/:reportId/comments')
  addReportComment(
    @CurrentUser() user: AuthenticatedUser,
    @Param('reportId') reportId: string,
    @Body() dto: CreateReportCommentDto,
  ) {
    return this.citizenService.addReportComment(user, reportId, dto);
  }

  @Post('reports/:reportId/upvote')
  toggleReportUpvote(
    @CurrentUser() user: AuthenticatedUser,
    @Param('reportId') reportId: string,
  ) {
    return this.citizenService.toggleReportUpvote(user, reportId);
  }

  @Post('reports/:reportId/flag')
  flagReport(
    @CurrentUser() user: AuthenticatedUser,
    @Param('reportId') reportId: string,
    @Body() dto: FlagReportDto,
  ) {
    return this.citizenService.flagReport(user, reportId, dto);
  }
}
