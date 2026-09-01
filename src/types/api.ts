import { FastifyRequest, FastifyReply } from 'fastify';
import { DB } from '@/db/connection';

export interface AppRequest extends FastifyRequest {
  db: DB;
  userId?: string;
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
