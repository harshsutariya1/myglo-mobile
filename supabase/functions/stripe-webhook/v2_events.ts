// Thin v2 events: changes to providers' connected accounts.

import { syncConnectAccount } from '../_shared/connect_accounts.ts';
import { Stripe } from '../_shared/stripe.ts';

export async function handleV2Event(event: Stripe.V2.Core.EventNotification): Promise<string> {
  const related = (event as { related_object?: { id?: string; type?: string } | null }).related_object;
  if (!event.type.startsWith('v2.core.account') || event.type.startsWith('v2.core.account_')) return 'ignored';
  if (!related?.id || related.type !== 'v2.core.account') return 'ignored';

  // Whatever changed (requirements, capability status, closure), fetch the
  // account as it is now and store that.
  const providerId = await syncConnectAccount(related.id);
  return providerId ? 'account_synced' : 'unknown_account';
}
