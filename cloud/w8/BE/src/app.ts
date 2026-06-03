import 'dotenv/config';
import { existsSync } from 'node:fs';
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { serveStatic } from '@hono/node-server/serve-static';
import { documentsApp } from './documents/documents.router';
import { annotationsApp } from './annotations/annotations.router';

export const app = new Hono();
const staticRoot = existsSync('./public/index.html')
  ? './public'
  : existsSync('./dist/public/index.html')
    ? './dist/public'
    : undefined;

// Global middleware
app.use('*', logger());
app.use(
  '*',
  cors({
    origin: process.env.FRONTEND_URL || '*',
    allowHeaders: [
      'Content-Type',
      'Authorization',
      'X-Amz-Date',
      'X-Api-Key',
      'X-Amz-Security-Token',
    ],
    allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  }),
);

// Route registration
app.route('/documents', documentsApp);
app.route('/annotations', annotationsApp);

app.get('/health', (c) => c.json({ status: 'ok', framework: 'hono' }));

if (staticRoot) {
  app.get('/assets/*', serveStatic({ root: staticRoot }));
  app.get('/', serveStatic({ path: `${staticRoot}/index.html` }));
  app.get('/app', serveStatic({ path: `${staticRoot}/index.html` }));
}
