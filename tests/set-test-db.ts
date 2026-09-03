// Runs in every Jest worker BEFORE any app module (and therefore before
// `@/config/env` reads it), so the whole suite talks to the test database.
import 'dotenv/config';
import { TEST_DATABASE_URL } from './helpers/test-db-url';

process.env.DATABASE_URL = TEST_DATABASE_URL;
process.env.NODE_ENV = 'test';
