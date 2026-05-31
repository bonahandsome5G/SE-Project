import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
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
import { AdminService } from './admin.service';
import { AdminReportQueryDto } from './dto/admin-report-query.dto';
import { BlockUserDto } from './dto/block-user.dto';
import { ReportActionDto } from './dto/report-action.dto';
import { UpdateReportStatusDto } from './dto/update-report-status.dto';
import { UserQueryDto } from './dto/user-query.dto';

@Controller('admin')
@UseGuards(SupabaseJwtGuard, RolesGuard)
@Roles(UserRole.admin, UserRole.dishub)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get()
  index(@CurrentUser() user: AuthenticatedUser) {
    return {
      module: 'admin',
      user,
      routes: [
        'dashboard',
        'reports',
        'reports/suspected-spam',
        'reports/flagged',
        'users',
      ],
    };
  }

  @Get('dashboard')
  getDashboardStats() {
    return this.adminService.getDashboardStats();
  }

  @Get('reports')
  getReports(@Query() query: AdminReportQueryDto) {
    return this.adminService.getReports(query);
  }

  @Get('reports/suspected-spam')
  getSuspectedSpamReports(@Query() query: AdminReportQueryDto) {
    return this.adminService.getSuspectedSpamReports(query);
  }

  @Get('reports/flagged')
  getFlaggedReports(@Query() query: AdminReportQueryDto) {
    return this.adminService.getFlaggedReports(query);
  }

  @Get('reports/:reportId')
  getReport(@Param('reportId') reportId: string) {
    return this.adminService.getReport(reportId);
  }

  @Patch('reports/:reportId/status')
  updateReportStatus(
    @CurrentUser() user: AuthenticatedUser,
    @Param('reportId') reportId: string,
    @Body() dto: UpdateReportStatusDto,
  ) {
    return this.adminService.updateReportStatus(user, reportId, dto);
  }

  @Post('reports/:reportId/accept')
  acceptReport(
    @CurrentUser() user: AuthenticatedUser,
    @Param('reportId') reportId: string,
    @Body() dto: ReportActionDto,
  ) {
    return this.adminService.acceptReport(user, reportId, dto);
  }

  @Post('reports/:reportId/reject')
  rejectReport(
    @CurrentUser() user: AuthenticatedUser,
    @Param('reportId') reportId: string,
    @Body() dto: ReportActionDto,
  ) {
    return this.adminService.rejectReport(user, reportId, dto);
  }

  @Get('users')
  getUsers(@Query() query: UserQueryDto) {
    return this.adminService.getUsers(query);
  }

  @Post('users/:userId/block')
  blockUser(
    @CurrentUser() user: AuthenticatedUser,
    @Param('userId') userId: string,
    @Body() dto: BlockUserDto,
  ) {
    return this.adminService.blockUser(user, userId, dto);
  }

  @Post('users/:userId/unblock')
  unblockUser(@Param('userId') userId: string) {
    return this.adminService.unblockUser(userId);
  }
}
