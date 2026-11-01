// Calls to the project's database functions through PostgREST.
//
// serviceRpc runs as the service role (for the worker and webhooks, which
// act on the system's behalf). userRpc runs as the caller, with their own
// access token, so the database's own role and assurance-level checks decide
// what they may do; Edge Functions never re-implement those checks.

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

const RPC_TIMEOUT_MS = 15_000;

/** A database function refused or failed. `code` is the RAISE EXCEPTION key. */
export class RpcError extends Error {
  constructor(
    readonly fn: string,
    readonly status: number,
    readonly code: string,
    readonly details: string | null,
    readonly sqlState: string | null,
  ) {
    super(`${fn} failed (${status}): ${code}`);
  }

  /** A refusal the caller caused (bad input, wrong role), not a fault. */
  get isExpected(): boolean {
    return this.sqlState === 'P0001' || this.sqlState === 'P0002' ||
      this.sqlState === '22023' || this.sqlState === '42501';
  }
}

export function supabaseConfigured(): boolean {
  return SUPABASE_URL !== '' && SERVICE_ROLE_KEY !== '' && ANON_KEY !== '';
}

export function serviceRpc<T = unknown>(fn: string, params: Record<string, unknown> = {}): Promise<T> {
  return rpc<T>(fn, params, SERVICE_ROLE_KEY, `Bearer ${SERVICE_ROLE_KEY}`);
}

/**
 * Updates an Auth user through the Auth admin API (service role), e.g. to
 * set `ban_duration`. Returns the HTTP status; 404 means the user is gone.
 */
export async function updateAuthUser(userId: string, attributes: Record<string, unknown>): Promise<number> {
  const response = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${encodeURIComponent(userId)}`, {
    method: 'PUT',
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(attributes),
    signal: AbortSignal.timeout(RPC_TIMEOUT_MS),
  });
  // Drain the body so the connection is released.
  await response.text();
  return response.status;
}

/** Runs `fn` as the user whose `Authorization: Bearer <jwt>` header is given. */
export function userRpc<T = unknown>(
  authorization: string,
  fn: string,
  params: Record<string, unknown> = {},
): Promise<T> {
  return rpc<T>(fn, params, ANON_KEY, authorization);
}

async function rpc<T>(
  fn: string,
  params: Record<string, unknown>,
  apiKey: string,
  authorization: string,
): Promise<T> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: {
      apikey: apiKey,
      Authorization: authorization,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(params),
    signal: AbortSignal.timeout(RPC_TIMEOUT_MS),
  });
  const text = await response.text();
  if (!response.ok) {
    let body: Record<string, unknown> = {};
    try {
      body = JSON.parse(text);
    } catch {
      // Not JSON (gateway error); keep the status.
    }
    throw new RpcError(
      fn,
      response.status,
      typeof body.message === 'string' ? body.message : `http_${response.status}`,
      typeof body.details === 'string' ? body.details : null,
      typeof body.code === 'string' ? body.code : null,
    );
  }
  return (text ? JSON.parse(text) : null) as T;
}
