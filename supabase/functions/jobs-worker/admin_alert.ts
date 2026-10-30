// Emails every admin about something that needs a person: a failed job, a
// dispute, a new report. Recipients come from private.admins (through
// list_admin_alert_recipients), never from the job.

import { serviceRpc } from '../_shared/supabase.ts';
import { failed, Job, JobResult, retry, succeeded } from './types.ts';

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
const ALERTS_FROM = Deno.env.get('ADMIN_ALERTS_EMAIL_FROM') ?? 'Myglo alerts <alerts@myglo.app>';
const SEND_TIMEOUT_MS = 10_000;

export async function sendAdminAlert(job: Job): Promise<JobResult> {
  const subject = text(job.payload.subject, 'Myglo needs attention');
  const body = text(job.payload.body, '');
  const severity = text(job.payload.severity, 'normal');
  if (!RESEND_API_KEY) return retry('RESEND_API_KEY is not set');

  const recipients = await serviceRpc<{ email: string }[]>('list_admin_alert_recipients');
  const to = recipients.map((r) => r.email).filter((email) => email.includes('@'));
  if (to.length === 0) return failed('no admin has an email address');

  const lines = [
    body,
    '',
    ...Object.entries(job.payload)
      .filter(([key, value]) => !['subject', 'body', 'severity'].includes(key) && value != null)
      .map(([key, value]) => `${key}: ${typeof value === 'string' ? value : JSON.stringify(value)}`),
    '',
    'Open the admin area in the Myglo app for details.',
  ];

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
      'Idempotency-Key': `admin-alert-${job.job_id}`,
    },
    body: JSON.stringify({
      from: ALERTS_FROM,
      to,
      subject: severity === 'high' ? `[Action needed] ${subject}` : subject,
      text: lines.join('\n'),
      tags: [{ name: 'category', value: 'admin_alert' }],
    }),
    signal: AbortSignal.timeout(SEND_TIMEOUT_MS),
  });
  const payload = await response.json().catch(() => ({}));
  if (response.ok) return succeeded({ message_id: payload?.id ?? null, recipients: to.length });

  const detail = `resend ${response.status}: ${payload?.message ?? payload?.name ?? 'unknown error'}`;
  return response.status === 429 || response.status >= 500 ? retry(detail) : failed(detail);
}

function text(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.trim() !== '' ? value.trim().slice(0, 2000) : fallback;
}
