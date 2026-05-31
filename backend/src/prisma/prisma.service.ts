import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  constructor() {
    const connectionString = process.env.DATABASE_URL;

    if (!connectionString || connectionString.includes('[PASSWORD]')) {
      super();
      return;
    }

    super({
      adapter: new PrismaPg({
        connectionString,
        ssl: { rejectUnauthorized: false },
      }),
    });
  }

  async onModuleInit() {
    if (!this.hasConfiguredDatabase()) {
      return;
    }

    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }

  private hasConfiguredDatabase() {
    const databaseUrl = process.env.DATABASE_URL;

    return Boolean(databaseUrl && !databaseUrl.includes('[PASSWORD]'));
  }
}
