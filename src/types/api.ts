import { DB } from '@/db/connection';
import type { SupportedLocale } from '@/i18n/locale';

/**
 * Every request carries these once the app.ts preHandler hook and
 * auth-guard.ts have run — declared once here via module augmentation so
 * every route handler gets real types on `request` instead of the
 * `(request: any, reply: any)` + eslint-disable boilerplate this used to
 * need everywhere. `db` and `locale` are always set (the hook that sets
 * them runs unconditionally, before auth-guard); `userId`/`userRole` are
 * optional since they're unset for public routes and unauthenticated
 * callers.
 */
declare module 'fastify' {
  interface FastifyRequest {
    db: DB;
    locale: SupportedLocale;
    userId?: string;
    userRole?: string;
  }
}

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  code: string;
}

export interface PaginationParams {
  page: number;
  limit: number;
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}
