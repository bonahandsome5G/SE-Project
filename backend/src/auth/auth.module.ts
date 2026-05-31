import { Module } from '@nestjs/common';

import { SupabaseJwtGuard } from './guards/supabase-jwt.guard';
import { RolesGuard } from './guards/roles.guard';

@Module({
  providers: [SupabaseJwtGuard, RolesGuard],
  exports: [SupabaseJwtGuard, RolesGuard],
})
export class AuthModule {}
