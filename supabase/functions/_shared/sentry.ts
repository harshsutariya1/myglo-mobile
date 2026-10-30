// Reports unexpected Edge Function errors to Sentry through its envelope
// endpoint, so the functions need no SDK dependency.
//
// Secrets
//   SENTRY_DSN_FUNCTIONS  the DSN of the Sentry project for server errors;
//                         without it errors are only logged.
//   SENTRY_ENVIRONMENT    optional, defaults to "supabase".

const DSN = Deno.env.get('SENTRY_DSN_FUNCTIONS') ?? '';
const ENVIRONMENT = Deno.env.get('SENTRY_ENVIRONMENT') ?? 'supabase';
const SEND_TIMEOUT_MS = 3_000;

interface ParsedDsn {
  endpoint: string;
  publicKey: string;
}

function parseDsn(dsn: string): ParsedDsn | null {
  try {
    const url = new URL(dsn);
    const projectId = url.pathname.replace(/^\/+/, '');
    if (!url.username || !projectId) return null;
    return {
      endpoint: `${url.protocol}//${url.host}/api/${projectId}/envelope/`,
      publicKey: url.username,
    };
  } catch {
    return null;
  }
}

const parsed = DSN ? parseDsn(DSN) : null;

export interface ErrorContext {
  /** The function reporting, e.g. "jobs-worker". */
  fn: string;
  tags?: Record<string, string>;
  extra?: Record<string, unknown>;
}

/** Logs the error and sends it to Sentry. Never throws. */
export async function captureException(error: unknown, context: ErrorContext): Promise<void> {
  console.error(`${context.fn}:`, error, context.extra ?? '');
  if (!parsed) return;

  const eventId = crypto.randomUUID().replace(/-/g, '');
  const err = error instanceof Error ? error : new Error(String(error));
  const event = {
    event_id: eventId,
    timestamp: Date.now() / 1000,
    platform: 'javascript',
    level: 'error',
    environment: ENVIRONMENT,
    server_name: context.fn,
    tags: { function: context.fn, ...context.tags },
    extra: context.extra,
    exception: {
      values: [{
        type: err.name,
        value: err.message,
        stacktrace: err.stack ? { frames: stackFrames(err.stack) } : undefined,
      }],
    },
  };
  const envelope = [
    JSON.stringify({ event_id: eventId, sent_at: new Date().toISOString() }),
    JSON.stringify({ type: 'event' }),
    JSON.stringify(event),
  ].join('\n');

  try {
    await fetch(parsed.endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-sentry-envelope',
        'X-Sentry-Auth': `Sentry sentry_version=7, sentry_key=${parsed.publicKey}, sentry_client=myglo-edge/1.0`,
      },
      body: envelope,
      signal: AbortSignal.timeout(SEND_TIMEOUT_MS),
    });
  } catch (sendError) {
    console.error(`${context.fn}: sentry send failed`, sendError);
  }
}

/** Sentry wants frames oldest-first; V8 stacks are newest-first. */
function stackFrames(stack: string): { function: string; filename: string; lineno?: number }[] {
  return stack
    .split('\n')
    .slice(1)
    .map((line) => {
      const match = line.match(/at (?:(.+?) \()?(.+?):(\d+):\d+\)?$/);
      return match
        ? { function: match[1] ?? '?', filename: match[2], lineno: Number(match[3]) }
        : { function: line.trim(), filename: '?' };
    })
    .reverse();
}
