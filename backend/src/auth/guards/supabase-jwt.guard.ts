import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createRemoteJWKSet, jwtVerify } from 'jose';

import { PrismaService } from '../../prisma/prisma.service';
import {
  AuthenticatedUser,
  SupabaseJwtPayload,
} from '../types/authenticated-user';

@Injectable()
export class SupabaseJwtGuard implements CanActivate {
  private readonly jwks: ReturnType<typeof createRemoteJWKSet>;

  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    const supabaseUrl = this.configService.get<string>('SUPABASE_URL');

    if (!supabaseUrl) {
      throw new Error('SUPABASE_URL is required for JWT verification');
    }

    this.jwks = createRemoteJWKSet(
      new URL('/auth/v1/.well-known/jwks.json', supabaseUrl),
    );
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<{
      headers: Record<string, string | undefined>;
      user?: AuthenticatedUser;
    }>();
    const token = this.extractBearerToken(request.headers.authorization);

    if (!token) {
      throw new UnauthorizedException('Missing bearer token');
    }

    const supabaseUrl = this.configService.get<string>('SUPABASE_URL');
    let supabasePayload: SupabaseJwtPayload;

    try {
      const { payload } = await jwtVerify(token, this.jwks, {
        issuer: `${supabaseUrl}/auth/v1`,
      });
      supabasePayload = payload as SupabaseJwtPayload;
    } catch {
      throw new UnauthorizedException('Invalid or expired bearer token');
    }

    if (!supabasePayload.sub) {
      throw new UnauthorizedException('Invalid bearer token subject');
    }

    const profile = await this.prisma.profile.findUnique({
      where: { id: supabasePayload.sub },
      select: {
        id: true,
        role: true,
        isBlocked: true,
        fullName: true,
      },
    });

    if (!profile) {
      throw new UnauthorizedException('Profile not found');
    }

    if (profile.isBlocked) {
      throw new UnauthorizedException('User is blocked');
    }

    request.user = {
      id: profile.id,
      email: supabasePayload.email,
      role: profile.role,
      fullName: profile.fullName,
    };

    return true;
  }

  private extractBearerToken(authorization?: string): string | undefined {
    const [type, token] = authorization?.split(' ') ?? [];
    return type?.toLowerCase() === 'bearer' ? token : undefined;
  }
}
