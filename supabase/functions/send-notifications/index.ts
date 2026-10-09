// Delivers queued booking notifications by email (Resend) and push (Firebase
// Cloud Messaging).
//
// The database calls this function through pg_net right after a booking
// event queues its deliveries, and a pg_cron sweeper calls it every minute to
// retry anything still due (see migrations 20261005130000_booking_notifications
// and 20261009120000_push_notifications).
//
// Work is claimed atomically in the database (FOR UPDATE SKIP LOCKED), so two
// invocations never pick up the same delivery. Every email carries a Resend
// Idempotency-Key so a retried delivery can't produce a second email; every
// push is tagged with its notification id, so a repeat replaces the first one
// on the device instead of stacking.
//
// The request body is just `{ "delivery_ids": [...] }` (or `{}` to process
// everything due). Content, recipients and state all come from the database,
// so a caller can't make this function send anything that wasn't queued.
//
// Secrets
//   RESEND_API_KEY            required to send email
//   NOTIFICATIONS_EMAIL_FROM  optional, defaults to "Myglo <bookings@myglo.app>"
//   FIREBASE_SERVICE_ACCOUNT  required to send push: the Firebase service
//                             account key JSON (Project settings → Service
//                             accounts → Generate new private key)
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY are provided by the platform.

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
const EMAIL_FROM = Deno.env.get('NOTIFICATIONS_EMAIL_FROM') ?? 'Myglo <bookings@myglo.app>';
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '';

const BATCH_SIZE = 20;
const SEND_TIMEOUT_MS = 10_000;
/** Matches the database sweeper: old news is worse than no news. */
const STALE_AFTER_MS = 12 * 60 * 60 * 1000;
/** A push about something hours old is noise; the in-app inbox still has it. */
const PUSH_STALE_AFTER_MS = 2 * 60 * 60 * 1000;
/** How long FCM keeps trying an offline device. */
const PUSH_TTL = '14400s';
/** Android channel created by the app (MainActivity.kt). */
const ANDROID_CHANNEL_ID = 'bookings';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

interface BookingSummary {
  reference: string;
  status: string;
  provider_name: string;
  client_name: string;
  date: string;
  time_range: string;
  time_zone: string;
  time_zone_abbrev: string | null;
  services: { name: string; price: string }[];
  total: string;
  location_type: 'studio' | 'client';
  address: string;
  payment_method: string;
  payment_status: string;
  cancellation_window_hours: number;
  cancellation_fee_percent: number;
  free_cancellation_until: string;
  late_cancellation: boolean;
  cancellation_fee: string | null;
}

interface Delivery {
  delivery_id: string;
  channel: string;
  attempt: number;
  recipient_email: string | null;
  recipient_name: string | null;
  recipient_role: 'customer' | 'provider';
  kind: string;
  title: string;
  body: string;
  created_at: string;
  booking: BookingSummary | null;
  notification_id: string;
  booking_id: string | null;
  /** Recipient's device tokens, newest first (push deliveries only). */
  push_tokens: string[] | null;
}

type Outcome = 'sent' | 'retry' | 'failed' | 'skipped';

interface DeliveryResult {
  outcome: Outcome;
  error?: string;
  messageId?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    console.error('send-notifications: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing');
    return json({ error: 'misconfigured' }, 500);
  }

  const ids = await requestedIds(req);

  let deliveries: Delivery[];
  try {
    deliveries = await rpc<Delivery[]>('claim_notification_deliveries', {
      p_delivery_ids: ids,
      p_limit: BATCH_SIZE,
    });
  } catch (error) {
    console.error('send-notifications: claim failed', error);
    return json({ error: 'claim_failed' }, 500);
  }

  const results = await Promise.all(
    deliveries.map(async (delivery) => {
      const result = await deliver(delivery);
      try {
        await rpc('complete_notification_delivery', {
          p_delivery_id: delivery.delivery_id,
          p_outcome: result.outcome,
          p_error: result.error ?? null,
          p_provider_message_id: result.messageId ?? null,
        });
      } catch (error) {
        // The claim lapses and the sweeper retries it; the idempotency key
        // stops Resend from sending the same email twice.
        console.error('send-notifications: complete failed', delivery.delivery_id, error);
      }
      if (result.outcome !== 'sent') {
        console.warn('send-notifications:', delivery.delivery_id, result.outcome, result.error ?? '');
      }
      return { id: delivery.delivery_id, outcome: result.outcome };
    }),
  );

  return json({ processed: results.length, results });
});

/** Delivery ids from the body, or null to process everything due. */
async function requestedIds(req: Request): Promise<string[] | null> {
  try {
    const body = await req.json();
    if (Array.isArray(body?.delivery_ids)) {
      return body.delivery_ids.filter((id: unknown) => typeof id === 'string' && UUID.test(id)).slice(0, 100);
    }
  } catch {
    // An empty or non-JSON body means "sweep".
  }
  return null;
}

function deliver(delivery: Delivery): Promise<DeliveryResult> {
  switch (delivery.channel) {
    case 'email':
      return deliverEmail(delivery);
    case 'push':
      return deliverPush(delivery);
    default:
      return Promise.resolve({ outcome: 'skipped', error: `unsupported channel: ${delivery.channel}` });
  }
}

async function deliverEmail(delivery: Delivery): Promise<DeliveryResult> {
  if (!delivery.recipient_email) {
    return { outcome: 'skipped', error: 'recipient has no email address' };
  }
  if (Date.now() - Date.parse(delivery.created_at) > STALE_AFTER_MS) {
    return { outcome: 'skipped', error: 'stale' };
  }
  if (!RESEND_API_KEY) {
    return { outcome: 'retry', error: 'RESEND_API_KEY is not set' };
  }

  const email = renderEmail(delivery);
  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
        'Idempotency-Key': `notification-delivery-${delivery.delivery_id}`,
      },
      body: JSON.stringify({
        from: EMAIL_FROM,
        to: [delivery.recipient_email],
        subject: email.subject,
        html: email.html,
        text: email.text,
        tags: [{ name: 'category', value: delivery.kind }],
      }),
      signal: AbortSignal.timeout(SEND_TIMEOUT_MS),
    });
    const payload = await response.json().catch(() => ({}));
    if (response.ok) return { outcome: 'sent', messageId: payload?.id };

    const detail = `resend ${response.status}: ${payload?.message ?? payload?.name ?? 'unknown error'}`;
    // Rate limits and server errors may succeed later; other 4xx won't.
    const transient = response.status === 429 || response.status >= 500;
    return { outcome: transient ? 'retry' : 'failed', error: detail };
  } catch (error) {
    return { outcome: 'retry', error: `send failed: ${error}` };
  }
}

// ---------------------------------------------------------------------------
// Push (FCM HTTP v1)
// ---------------------------------------------------------------------------

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

type TokenResult = 'sent' | 'unregistered' | 'transient' | 'failed';

let serviceAccount: ServiceAccount | null | undefined;
let accessToken: { value: string; expiresAt: number } | null = null;

function firebaseServiceAccount(): ServiceAccount | null {
  if (serviceAccount !== undefined) return serviceAccount;
  try {
    const parsed = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
    serviceAccount = parsed?.project_id && parsed?.client_email && parsed?.private_key
      ? { project_id: parsed.project_id, client_email: parsed.client_email, private_key: parsed.private_key }
      : null;
  } catch {
    serviceAccount = null;
  }
  return serviceAccount;
}

async function deliverPush(delivery: Delivery): Promise<DeliveryResult> {
  const tokens = [...new Set(delivery.push_tokens ?? [])];
  if (tokens.length === 0) {
    return { outcome: 'skipped', error: 'recipient has no registered devices' };
  }
  if (Date.now() - Date.parse(delivery.created_at) > PUSH_STALE_AFTER_MS) {
    return { outcome: 'skipped', error: 'stale' };
  }
  const account = firebaseServiceAccount();
  if (!account) {
    return { outcome: 'retry', error: 'FIREBASE_SERVICE_ACCOUNT is not set or invalid' };
  }

  let bearer: string;
  try {
    bearer = await googleAccessToken(account);
  } catch (error) {
    return { outcome: 'retry', error: `fcm auth failed: ${error}` };
  }

  const results = await Promise.all(tokens.map((token) => sendToToken(account, bearer, token, delivery)));

  const unregistered = tokens.filter((_, i) => results[i].result === 'unregistered');
  if (unregistered.length > 0) {
    try {
      await rpc('remove_push_tokens', { p_tokens: unregistered });
    } catch (error) {
      console.error('send-notifications: removing stale push tokens failed', error);
    }
  }

  const sent = results.find((r) => r.result === 'sent');
  if (sent) return { outcome: 'sent', messageId: sent.messageId };
  const errors = results.map((r) => r.error).filter(Boolean).join('; ').slice(0, 480);
  if (results.some((r) => r.result === 'transient')) return { outcome: 'retry', error: errors };
  if (results.every((r) => r.result === 'unregistered')) {
    return { outcome: 'skipped', error: 'no registered devices left' };
  }
  return { outcome: 'failed', error: errors };
}

async function sendToToken(
  account: ServiceAccount,
  bearer: string,
  token: string,
  delivery: Delivery,
): Promise<{ result: TokenResult; messageId?: string; error?: string }> {
  const data: Record<string, string> = {
    notification_id: delivery.notification_id,
    kind: delivery.kind,
  };
  if (delivery.booking_id) data.booking_id = delivery.booking_id;

  try {
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: delivery.title, body: delivery.body },
          data,
          android: {
            priority: 'HIGH',
            ttl: PUSH_TTL,
            notification: {
              channel_id: ANDROID_CHANNEL_ID,
              tag: delivery.notification_id,
              icon: 'ic_stat_notification',
              color: BRAND.pink,
              default_sound: true,
            },
          },
          apns: {
            headers: { 'apns-priority': '10' },
            payload: { aps: { sound: 'default', 'thread-id': delivery.booking_id ?? delivery.kind } },
          },
        },
      }),
      signal: AbortSignal.timeout(SEND_TIMEOUT_MS),
    });
    const payload = await response.json().catch(() => ({}));
    if (response.ok) return { result: 'sent', messageId: payload?.name };

    if (response.status === 401) accessToken = null;
    const status: string = payload?.error?.status ?? '';
    const message: string = payload?.error?.message ?? '';
    const code: string = (payload?.error?.details ?? [])
      .map((d: { errorCode?: string }) => d?.errorCode)
      .find(Boolean) ?? '';
    const detail = `fcm ${response.status} ${code || status}: ${message}`.trim();

    if (code === 'UNREGISTERED' || code === 'SENDER_ID_MISMATCH' || status === 'NOT_FOUND'
      || (status === 'INVALID_ARGUMENT' && /registration token/i.test(message))) {
      return { result: 'unregistered', error: detail };
    }
    if (response.status === 401 || response.status === 429 || response.status >= 500) {
      return { result: 'transient', error: detail };
    }
    return { result: 'failed', error: detail };
  } catch (error) {
    return { result: 'transient', error: `fcm send failed: ${error}` };
  }
}

/** OAuth access token for FCM, cached until shortly before it expires. */
async function googleAccessToken(account: ServiceAccount): Promise<string> {
  if (accessToken && accessToken.expiresAt - Date.now() > 5 * 60 * 1000) return accessToken.value;

  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(JSON.stringify({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned)),
  );
  const assertion = `${unsigned}.${base64Url(signature)}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
    signal: AbortSignal.timeout(SEND_TIMEOUT_MS),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || typeof payload?.access_token !== 'string') {
    throw new Error(`token endpoint ${response.status}: ${payload?.error_description ?? payload?.error ?? 'no token'}`);
  }
  accessToken = {
    value: payload.access_token,
    expiresAt: Date.now() + (Number(payload.expires_in) || 3600) * 1000,
  };
  return accessToken.value;
}

function pemToDer(pem: string): ArrayBuffer {
  const body = pem.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, '').replace(/\s+/g, '');
  const bytes = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return bytes.buffer;
}

function base64Url(input: string | Uint8Array): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function rpc<T = unknown>(fn: string, params: Record<string, unknown>): Promise<T> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(params),
  });
  if (!response.ok) {
    throw new Error(`${fn} failed with ${response.status}: ${await response.text()}`);
  }
  const text = await response.text();
  return (text ? JSON.parse(text) : null) as T;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

const BRAND = {
  ink: '#140000',
  body: '#4A3B3B',
  muted: '#8C7B7B',
  pink: '#FC69C3',
  canvas: '#FAF6F5',
  card: '#FFF6F3',
  border: '#F1E4E0',
};

const FONT = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";

interface Badge {
  label: string;
  color: string;
  background: string;
}

function badgeFor(kind: string, booking: BookingSummary | null): Badge {
  switch (kind) {
    case 'booking_new':
    case 'booking_confirmed':
      return { label: 'Confirmed', color: '#15803D', background: '#DCFCE7' };
    case 'booking_request':
    case 'booking_requested':
      return { label: 'Pending approval', color: '#B45309', background: '#FEF3C7' };
    case 'booking_declined':
      return { label: 'Declined', color: '#B91C1C', background: '#FEE2E2' };
    case 'booking_cancelled':
      return {
        label: booking?.late_cancellation ? 'Late cancellation' : 'Cancelled',
        color: '#B91C1C',
        background: '#FEE2E2',
      };
    case 'booking_expired':
      return { label: 'Expired', color: '#57534E', background: '#F5F5F4' };
    case 'booking_no_show':
      return { label: 'Missed', color: '#B91C1C', background: '#FEE2E2' };
    case 'booking_completed':
      return { label: 'Completed', color: '#15803D', background: '#DCFCE7' };
    default:
      return { label: 'Reminder', color: '#BE185D', background: '#FCE7F3' };
  }
}

function renderEmail(delivery: Delivery): { subject: string; html: string; text: string } {
  const booking = delivery.booking;
  const forProvider = delivery.recipient_role === 'provider';
  const counterpart = booking ? (forProvider ? booking.client_name : booking.provider_name) : null;
  const subject = counterpart ? `${delivery.title} · ${counterpart}` : delivery.title;
  const badge = badgeFor(delivery.kind, booking);
  const greeting = delivery.recipient_name ? `Hi ${delivery.recipient_name.split(' ')[0]},` : 'Hi,';
  const zone = booking?.time_zone_abbrev ?? '';
  const zoneLabel = booking?.time_zone === 'Australia/Brisbane'
    ? `Gold Coast time (${zone || 'AEST'})`
    : (booking ? `${booking.time_zone.replace(/_/g, ' ')} time` : '');

  const rows: string[] = [];
  const textLines: string[] = [];
  if (booking) {
    rows.push(detailRow('When', `${esc(booking.date)}<br>${esc(booking.time_range)}${zone ? ` ${esc(zone)}` : ''}`));
    textLines.push(`When: ${booking.date}, ${booking.time_range}${zone ? ` ${zone}` : ''}`);

    const where = booking.location_type === 'studio' ? `At ${booking.provider_name}'s studio` : "At the client's place";
    rows.push(detailRow('Where', `${esc(where)}<br><span style="color:${BRAND.muted};">${esc(booking.address)}</span>`));
    textLines.push(`Where: ${where} — ${booking.address}`);

    rows.push(detailRow(forProvider ? 'Client' : 'Provider', esc(forProvider ? booking.client_name : booking.provider_name)));
    textLines.push(`${forProvider ? 'Client' : 'Provider'}: ${forProvider ? booking.client_name : booking.provider_name}`);

    const services = booking.services
      .map((s) => `<tr><td style="padding:2px 0;font-size:14px;color:${BRAND.ink};">${esc(s.name)}</td>`
        + `<td align="right" style="padding:2px 0;font-size:14px;color:${BRAND.ink};">${esc(s.price)}</td></tr>`)
      .join('');
    rows.push(detailRow('Services', `<table role="presentation" width="100%" cellpadding="0" cellspacing="0">${services}</table>`));
    textLines.push(...booking.services.map((s) => `  ${s.name} — ${s.price}`));

    const cash = booking.payment_method === 'cash';
    const paymentNote = !cash
      ? ''
      : booking.payment_status === 'paid'
        ? 'Paid in cash'
        : booking.payment_status === 'void'
          ? 'Nothing to pay'
          : forProvider ? 'Collect in cash at the appointment' : 'Pay in cash at your appointment';
    rows.push(detailRow(
      'Total',
      `<span style="font-size:18px;font-weight:800;color:${BRAND.ink};">${esc(booking.total)}</span>`
        + (paymentNote ? `<br><span style="color:${BRAND.muted};">${esc(paymentNote)}</span>` : ''),
    ));
    textLines.push(`Total: ${booking.total}${paymentNote ? ` (${paymentNote})` : ''}`);

    if (booking.cancellation_fee) {
      rows.push(detailRow('Fee owed', esc(booking.cancellation_fee)));
      textLines.push(`Fee owed: ${booking.cancellation_fee}`);
    }

    rows.push(detailRow('Reference', `<span style="font-family:Menlo,Consolas,monospace;letter-spacing:1px;">${esc(booking.reference)}</span>`));
    textLines.push(`Reference: ${booking.reference}`);
  }

  const policy = booking && !forProvider && ['booking_confirmed', 'booking_requested'].includes(delivery.kind)
    ? policyLine(booking)
    : null;

  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<title>${esc(subject)}</title>
</head>
<body style="margin:0;padding:0;background:${BRAND.canvas};">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">${esc(delivery.body)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${BRAND.canvas};padding:32px 12px;font-family:${FONT};">
<tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#FFFFFF;border:1px solid ${BRAND.border};border-radius:20px;">
<tr><td style="padding:28px 28px 0;font-size:22px;font-weight:800;letter-spacing:-0.4px;color:${BRAND.ink};">my<span style="color:${BRAND.pink};">glo</span></td></tr>
<tr><td style="padding:22px 28px 0;">
<span style="display:inline-block;padding:6px 12px;border-radius:999px;background:${badge.background};color:${badge.color};font-size:12px;font-weight:700;letter-spacing:0.2px;">${esc(badge.label)}</span>
<h1 style="margin:16px 0 10px;font-size:24px;line-height:1.25;font-weight:800;color:${BRAND.ink};">${esc(delivery.title)}</h1>
<p style="margin:0 0 6px;font-size:15px;line-height:1.55;color:${BRAND.body};">${esc(greeting)}</p>
<p style="margin:0;font-size:15px;line-height:1.55;color:${BRAND.body};">${esc(delivery.body)}</p>
</td></tr>
${rows.length ? `<tr><td style="padding:22px 28px 0;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${BRAND.card};border-radius:16px;">
<tr><td style="padding:6px 20px;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0">${detailRows(rows)}</table>
</td></tr>
</table>
</td></tr>` : ''}
${policy ? `<tr><td style="padding:16px 28px 0;font-size:13px;line-height:1.5;color:${BRAND.body};">${esc(policy)}</td></tr>` : ''}
<tr><td style="padding:22px 28px 28px;font-size:12.5px;line-height:1.55;color:${BRAND.muted};">
Open the Myglo app to view or manage this booking.${zoneLabel ? `<br>Times are shown in ${esc(zoneLabel)}.` : ''}
</td></tr>
</table>
<p style="margin:18px 0 0;font-size:11.5px;line-height:1.5;color:${BRAND.muted};">You're receiving this email because of a booking on Myglo.</p>
</td></tr>
</table>
</body>
</html>`;

  const text = [
    greeting,
    '',
    delivery.title,
    delivery.body,
    ...(textLines.length ? ['', ...textLines] : []),
    ...(policy ? ['', policy] : []),
    '',
    'Open the Myglo app to view or manage this booking.',
    ...(zoneLabel ? [`Times are shown in ${zoneLabel}.`] : []),
  ].join('\n');

  return { subject, html, text };
}

function policyLine(booking: BookingSummary): string | null {
  if (booking.cancellation_window_hours <= 0) return 'You can cancel for free any time before your appointment.';
  const fee = booking.cancellation_fee_percent > 0
    ? ` After that, a ${booking.cancellation_fee_percent}% late-cancellation fee applies.`
    : ' After that, cancellations are recorded as late.';
  return `Free cancellation until ${booking.free_cancellation_until}.${fee}`;
}

function detailRow(label: string, valueHtml: string): string {
  return `<tr>
<td valign="top" style="padding:12px 12px 12px 0;width:96px;font-size:12px;font-weight:700;letter-spacing:0.6px;text-transform:uppercase;color:${BRAND.muted};">${esc(label)}</td>
<td valign="top" style="padding:12px 0;font-size:14px;line-height:1.5;color:${BRAND.ink};">${valueHtml}</td>
</tr>`;
}

/** Detail rows separated by hairlines (none after the last). */
function detailRows(rows: string[]): string {
  const divider = `<tr><td colspan="2" style="height:1px;line-height:1px;font-size:0;background:${BRAND.border};">&nbsp;</td></tr>`;
  return rows.join(divider);
}

function esc(value: string | null | undefined): string {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
