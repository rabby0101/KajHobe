-- ============================================================================
-- A1 (part 1/2): add the 'resolved' escrow state.
--
-- Split into its own migration because a new enum label must be committed before
-- any later statement/function can use it (Postgres can't use a freshly-added
-- enum value in the same transaction). The dispute table + RPCs that reference
-- 'resolved' live in the follow-up migration 20260609020001-deal-disputes.sql.
--
-- 'resolved' = a dispute was settled by an admin, who recorded how the held
-- amount was split between a buyer refund and a provider payout (either may be 0).
-- ============================================================================

ALTER TYPE public.escrow_state ADD VALUE IF NOT EXISTS 'resolved';
