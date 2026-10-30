/** A job claimed from private.jobs (see claim_jobs). */
export interface Job {
  job_id: string;
  kind: string;
  idempotency_key: string;
  payload: Record<string, unknown>;
  booking_id: string | null;
  attempt: number;
}

/** How a job ended; recorded by complete_job. */
export interface JobResult {
  outcome: 'succeeded' | 'retry' | 'failed';
  error?: string;
  result?: Record<string, unknown>;
}

export type JobHandler = (job: Job) => Promise<JobResult>;

export const succeeded = (result?: Record<string, unknown>): JobResult => ({ outcome: 'succeeded', result });
export const retry = (error: string): JobResult => ({ outcome: 'retry', error });
export const failed = (error: string): JobResult => ({ outcome: 'failed', error });
