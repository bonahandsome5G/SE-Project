import { UserRole } from '@prisma/client';

export type SupabaseJwtPayload = {
  sub: string;
  email?: string;
  role?: string;
  aud?: string;
  exp?: number;
  iat?: number;
};

export type AuthenticatedUser = {
  id: string;
  email?: string;
  role: UserRole;
  fullName?: string | null;
};
