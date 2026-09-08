import { FastifyRequest, FastifyReply } from 'fastify';
import { DB } from '@/db/connection';
import type { SupportedLocale } from '@/i18n/locale';

export interface AppRequest extends FastifyRequest {
  db: DB;
  userId?: string;
  locale: SupportedLocale;
}

export interface AppReply extends FastifyReply {}

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
