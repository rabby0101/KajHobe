// Escrow state presentation — mirrors the iOS EscrowState enum + EscrowSectionView.

export type EscrowState =
  | 'pending'
  | 'held'
  | 'released'
  | 'paid_out'
  | 'refunded'
  | 'failed'
  | 'resolved';

export interface EscrowStateMeta {
  label: string;
  /** Tailwind text/badge color classes. */
  className: string;
  icon: 'Clock' | 'Lock' | 'ArrowUpRight' | 'CheckCircle2' | 'Undo2' | 'XCircle' | 'Scale';
}

export const ESCROW_STATE_META: Record<EscrowState, EscrowStateMeta> = {
  pending:  { label: 'Pending',  className: 'bg-orange-100 text-orange-700',  icon: 'Clock' },
  held:     { label: 'Held in escrow', className: 'bg-blue-100 text-blue-700', icon: 'Lock' },
  released: { label: 'Released', className: 'bg-purple-100 text-purple-700',   icon: 'ArrowUpRight' },
  paid_out: { label: 'Paid out', className: 'bg-green-100 text-green-700',     icon: 'CheckCircle2' },
  refunded: { label: 'Refunded', className: 'bg-gray-100 text-gray-700',       icon: 'Undo2' },
  failed:   { label: 'Failed',   className: 'bg-red-100 text-red-700',         icon: 'XCircle' },
  resolved: { label: 'Resolved', className: 'bg-indigo-100 text-indigo-700',   icon: 'Scale' },
};

/** Escrow states in which the deal's payment is actually funded. */
export const FUNDED_STATES: ReadonlySet<EscrowState> = new Set(['held', 'released', 'paid_out']);

export function isFunded(state: EscrowState): boolean {
  return FUNDED_STATES.has(state);
}

export function formatTaka(amount: number): string {
  return `৳${Math.round(amount).toLocaleString()}`;
}

/** Role-aware status copy (parity with iOS EscrowSectionView.roleCopy). */
export function escrowRoleCopy(state: EscrowState, isBuyer: boolean): string {
  switch (state) {
    case 'pending':
      return isBuyer ? 'Payment not completed for this deal.' : "Waiting for the client's payment.";
    case 'held':
      return isBuyer
        ? 'Your payment is held safely in escrow until the work is done.'
        : 'Payment is secured in escrow and will be released when the deal completes.';
    case 'released':
      return isBuyer
        ? 'Deal complete — the payment is being released to the provider.'
        : 'Deal complete — your payout is being processed.';
    case 'paid_out':
      return isBuyer ? 'The provider has been paid. Thank you!' : "You've been paid for this deal.";
    case 'refunded':
      return 'This payment was refunded to the buyer.';
    case 'failed':
      return 'The last payment attempt failed.';
    case 'resolved':
      return 'A dispute on this deal was resolved by an admin.';
  }
}

/** Bangladeshi mobile number format used for bKash payout accounts (01XXXXXXXXX). */
export function isValidBkashNumber(num: string): boolean {
  return /^01\d{9}$/.test(num.trim());
}
