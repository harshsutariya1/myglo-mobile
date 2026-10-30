// Small HTTP helpers shared by the Edge Functions.

/** An error with an HTTP status and a stable code the app can switch on. */
export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message?: string,
  ) {
    super(message ?? code);
  }
}

/**
 * Origins allowed to call user-facing functions from a browser (the future
 * Flutter web admin). Empty by default: the mobile app doesn't send an Origin.
 * Set ALLOWED_WEB_ORIGINS to a comma-separated list to allow one.
 */
const ALLOWED_WEB_ORIGINS = (Deno.env.get('ALLOWED_WEB_ORIGINS') ?? '')
  .split(',')
  .map((origin) => origin.trim())
  .filter((origin) => origin.length > 0);

function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get('Origin');
  if (!origin || !ALLOWED_WEB_ORIGINS.includes(origin)) return {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    Vary: 'Origin',
  };
}

/** Answers a CORS preflight, or returns null for any other request. */
export function preflight(req: Request): Response | null {
  if (req.method !== 'OPTIONS') return null;
  return new Response(null, { status: 204, headers: corsHeaders(req) });
}

export function json(body: unknown, status = 200, req?: Request): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...(req ? corsHeaders(req) : {}) },
  });
}

/** `{ "error": code }` with the error's status (500 for anything unexpected). */
export function errorJson(error: unknown, req?: Request): Response {
  if (error instanceof HttpError) {
    return json({ error: error.code, message: error.message }, error.status, req);
  }
  return json({ error: 'internal_error' }, 500, req);
}

/** The request's JSON body as an object, or `{}` if it has none. */
export async function readJson(req: Request): Promise<Record<string, unknown>> {
  try {
    const body = await req.json();
    return body && typeof body === 'object' && !Array.isArray(body) ? body as Record<string, unknown> : {};
  } catch {
    return {};
  }
}

export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** A required UUID field from a request body. */
export function requireUuid(body: Record<string, unknown>, field: string): string {
  const value = body[field];
  if (typeof value !== 'string' || !UUID.test(value)) {
    throw new HttpError(400, 'invalid_request', `${field} must be a UUID`);
  }
  return value;
}
