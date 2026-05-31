import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { CitizenController } from './citizen.controller';
import { CitizenService } from './citizen.service';

@Module({
  imports: [AuthModule],
  controllers: [CitizenController],
  providers: [CitizenService],
})
export class CitizenModule {}
