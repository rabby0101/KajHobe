// ---------------------------------------------------------------------------
// KajHobe admin payout panel — PROTOTYPE (localhost only, NO login).
//
// Lists deals whose escrow is `released` (buyer paid, both parties approved
// completion) and lets an admin record the manual bKash payout, flipping the
// escrow `released -> paid_out` via the service-role RPC escrow_service_mark_paid_out.
//
// The Supabase SERVICE ROLE key lives here (server-side) and bypasses RLS so we
// can read the provider's private bKash number. It must NEVER be shipped to a
// browser. Do not expose this server beyond localhost.
// ---------------------------------------------------------------------------
import 'dotenv/config';
import express from 'express';
import { createClient } from '@supabase/supabase-js';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SERVICE_ROLE_KEY;
const PORT = process.env.PORT || 4000;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error('\n  Missing SUPABASE_URL or SERVICE_ROLE_KEY. Copy .env.example to .env and fill them in.\n');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const app = express();
app.use(express.json());

const __dirname = dirname(fileURLToPath(import.meta.url));
app.use(express.static(join(__dirname, 'public')));

// Helper: index an array of rows by a key for cheap lookups.
const indexBy = (rows, key) => Object.fromEntries((rows || []).map((r) => [r[key], r]));

// GET /api/payouts — escrows awaiting payout (state = 'released'), enriched with
// who to pay, the provider's bKash number, amount, and the deal/job context.
app.get('/api/payouts', async (req, res) => {
  try {
    const { data: escrows, error } = await supabase
      .from('escrow_transactions')
      .select('id, deal_id, client_id, provider_id, amount, provider_amount, provider_msisdn, currency, released_at, notes')
      .eq('state', 'released')
      .order('released_at', { ascending: true });
    if (error) throw error;

    if (!escrows || escrows.length === 0) return res.json({ payouts: [] });

    const dealIds = [...new Set(escrows.map((e) => e.deal_id).filter(Boolean))];
    const userIds = [...new Set(escrows.flatMap((e) => [e.client_id, e.provider_id]).filter(Boolean))];
    const providerIds = [...new Set(escrows.map((e) => e.provider_id).filter(Boolean))];

    const [{ data: deals }, { data: profiles }, { data: payoutAccounts }] = await Promise.all([
      supabase.from('deals').select('id, job_id, agreed_amount').in('id', dealIds),
      supabase.from('profiles').select('id, full_name, email').in('id', userIds),
      supabase.from('provider_payout_accounts').select('user_id, bkash_number').in('user_id', providerIds),
    ]);

    const jobIds = [...new Set((deals || []).map((d) => d.job_id).filter(Boolean))];
    const { data: jobs } = jobIds.length
      ? await supabase.from('jobs').select('id, title, category').in('id', jobIds)
      : { data: [] };

    const dealById = indexBy(deals, 'id');
    const profileById = indexBy(profiles, 'id');
    const jobById = indexBy(jobs, 'id');
    const payoutByUser = indexBy(payoutAccounts, 'user_id');

    const payouts = escrows.map((e) => {
      const deal = dealById[e.deal_id] || {};
      const job = jobById[deal.job_id] || {};
      const provider = profileById[e.provider_id] || {};
      const client = profileById[e.client_id] || {};
      const account = payoutByUser[e.provider_id] || {};
      return {
        escrow_id: e.id,
        deal_id: e.deal_id,
        amount: e.amount,
        provider_amount: e.provider_amount,
        currency: e.currency || 'BDT',
        released_at: e.released_at,
        notes: e.notes,
        job_title: job.title || '(unknown job)',
        job_category: job.category || null,
        provider_name: provider.full_name || provider.email || '(unknown provider)',
        client_name: client.full_name || client.email || '(unknown client)',
        // bKash number to verify manually before sending money:
        provider_bkash_current: account.bkash_number || null,   // live from payout account
        provider_bkash_snapshot: e.provider_msisdn || null,     // frozen at release time
      };
    });

    res.json({ payouts });
  } catch (err) {
    console.error('GET /api/payouts failed:', err.message || err);
    res.status(500).json({ error: err.message || String(err) });
  }
});

// POST /api/payouts/:escrowId/approve — record the manual payout.
// Body: { trx_id?, notes? }. Flips released -> paid_out.
app.post('/api/payouts/:escrowId/approve', async (req, res) => {
  try {
    const { escrowId } = req.params;
    const { trx_id, notes } = req.body || {};
    const { data, error } = await supabase.rpc('escrow_service_mark_paid_out', {
      p_escrow_id: escrowId,
      p_notes: notes || null,
      p_trx_id: trx_id || null,
    });
    if (error) throw error;
    res.json({ ok: true, escrow: data });
  } catch (err) {
    console.error('POST approve failed:', err.message || err);
    res.status(400).json({ error: err.message || String(err) });
  }
});

// GET /api/disputes — open disputes awaiting an admin decision, enriched with the
// deal/job context, both parties' names, the held amount, and the provider's bKash
// number (so the admin can pay the provider's share if they award one).
app.get('/api/disputes', async (req, res) => {
  try {
    const { data: disputes, error } = await supabase
      .from('deal_disputes')
      .select('id, deal_id, raised_by, reason, created_at')
      .eq('status', 'open')
      .order('created_at', { ascending: true });
    if (error) throw error;
    if (!disputes || disputes.length === 0) return res.json({ disputes: [] });

    const dealIds = [...new Set(disputes.map((d) => d.deal_id).filter(Boolean))];
    const [{ data: deals }, { data: escrows }] = await Promise.all([
      supabase.from('deals').select('id, job_id, client_id, provider_id, agreed_amount').in('id', dealIds),
      supabase.from('escrow_transactions')
        .select('id, deal_id, amount, provider_amount, provider_msisdn, currency, state').in('deal_id', dealIds),
    ]);
    const dealById = indexBy(deals, 'id');
    const escrowByDeal = indexBy(escrows, 'deal_id');

    const userIds = [...new Set((deals || []).flatMap((d) => [d.client_id, d.provider_id]).filter(Boolean))];
    const providerIds = [...new Set((deals || []).map((d) => d.provider_id).filter(Boolean))];
    const jobIds = [...new Set((deals || []).map((d) => d.job_id).filter(Boolean))];

    const [{ data: profiles }, { data: payoutAccounts }, { data: jobs }] = await Promise.all([
      supabase.from('profiles').select('id, full_name, email').in('id', userIds.length ? userIds : ['00000000-0000-0000-0000-000000000000']),
      supabase.from('provider_payout_accounts').select('user_id, bkash_number').in('user_id', providerIds.length ? providerIds : ['00000000-0000-0000-0000-000000000000']),
      jobIds.length ? supabase.from('jobs').select('id, title, category').in('id', jobIds) : Promise.resolve({ data: [] }),
    ]);
    const profileById = indexBy(profiles, 'id');
    const payoutByUser = indexBy(payoutAccounts, 'user_id');
    const jobById = indexBy(jobs, 'id');

    const out = disputes.map((di) => {
      const deal = dealById[di.deal_id] || {};
      const escrow = escrowByDeal[di.deal_id] || {};
      const job = jobById[deal.job_id] || {};
      const provider = profileById[deal.provider_id] || {};
      const client = profileById[deal.client_id] || {};
      const account = payoutByUser[deal.provider_id] || {};
      const raiser = profileById[di.raised_by] || {};
      return {
        dispute_id: di.id,
        deal_id: di.deal_id,
        escrow_id: escrow.id || null,
        escrow_state: escrow.state || null,
        amount: escrow.amount ?? deal.agreed_amount ?? 0,
        currency: escrow.currency || 'BDT',
        reason: di.reason,
        raised_at: di.created_at,
        raised_by_name: raiser.full_name || raiser.email || '(unknown)',
        job_title: job.title || '(unknown job)',
        job_category: job.category || null,
        provider_name: provider.full_name || provider.email || '(unknown provider)',
        client_name: client.full_name || client.email || '(unknown client)',
        provider_bkash: account.bkash_number || escrow.provider_msisdn || null,
      };
    });
    res.json({ disputes: out });
  } catch (err) {
    console.error('GET /api/disputes failed:', err.message || err);
    res.status(500).json({ error: err.message || String(err) });
  }
});

// POST /api/disputes/:escrowId/resolve — settle a dispute with a refund/payout
// split. Body: { refund_amount, payout_amount, refund_trx?, payout_trx?, notes? }.
// Flips the held escrow -> resolved and closes the deal (DB RPC enforces that
// refund + payout <= amount).
app.post('/api/disputes/:escrowId/resolve', async (req, res) => {
  try {
    const { escrowId } = req.params;
    const { refund_amount, payout_amount, refund_trx, payout_trx, notes } = req.body || {};
    const refund = Math.trunc(Number(refund_amount) || 0);
    const payout = Math.trunc(Number(payout_amount) || 0);
    if (refund < 0 || payout < 0) throw new Error('amounts must be >= 0');
    const { data, error } = await supabase.rpc('escrow_service_resolve_dispute', {
      p_escrow_id: escrowId,
      p_refund_amount: refund,
      p_payout_amount: payout,
      p_refund_trx: refund_trx || null,
      p_payout_trx: payout_trx || null,
      p_notes: notes || 'Resolved via admin panel',
    });
    if (error) throw error;
    res.json({ ok: true, escrow: data });
  } catch (err) {
    console.error('POST resolve failed:', err.message || err);
    res.status(400).json({ error: err.message || String(err) });
  }
});

// --- Provider verifications -------------------------------------------------
// Manual review of provider applications: NID + phone + certificates + work
// demos. NID/certificate files live in PRIVATE Storage buckets, so we mint
// short-lived signed URLs for the reviewer. Approve/reject call the service-role
// RPCs which flip profiles.is_verified_provider and refresh public_profiles.

const NID_BUCKET = 'provider-nid';
const CERT_BUCKET = 'provider-certificates';

// Best-effort signed URL; returns null if the object is missing.
async function signed(bucket, path, expires = 600) {
  if (!path) return null;
  const { data, error } = await supabase.storage.from(bucket).createSignedUrl(path, expires);
  if (error) return null;
  return data?.signedUrl || null;
}

// GET /api/verifications — pending applications, enriched + signed file URLs.
app.get('/api/verifications', async (req, res) => {
  try {
    const { data: rows, error } = await supabase
      .from('provider_verifications')
      .select('user_id, status, nid_number, nid_front_path, nid_back_path, phone, phone_verified, certificate_paths, demo_video_urls, submitted_at')
      .eq('status', 'pending')
      .order('submitted_at', { ascending: true });
    if (error) throw error;
    if (!rows || rows.length === 0) return res.json({ verifications: [] });

    const userIds = [...new Set(rows.map((r) => r.user_id).filter(Boolean))];
    const { data: profiles } = await supabase
      .from('profiles').select('id, full_name, email').in('id', userIds);
    const profileById = indexBy(profiles, 'id');

    const verifications = await Promise.all(rows.map(async (r) => {
      const p = profileById[r.user_id] || {};
      const certPaths = Array.isArray(r.certificate_paths) ? r.certificate_paths : [];
      const [nidFront, nidBack, certUrls] = await Promise.all([
        signed(NID_BUCKET, r.nid_front_path),
        signed(NID_BUCKET, r.nid_back_path),
        Promise.all(certPaths.map((path) => signed(CERT_BUCKET, path))),
      ]);
      return {
        user_id: r.user_id,
        applicant_name: p.full_name || p.email || '(unknown)',
        applicant_email: p.email || null,
        nid_number: r.nid_number,
        phone: r.phone,
        phone_verified: r.phone_verified,
        submitted_at: r.submitted_at,
        nid_front_url: nidFront,
        nid_back_url: nidBack,
        certificate_urls: (certUrls || []).filter(Boolean),
        demo_video_urls: Array.isArray(r.demo_video_urls) ? r.demo_video_urls : [],
      };
    }));

    res.json({ verifications });
  } catch (err) {
    console.error('GET /api/verifications failed:', err.message || err);
    res.status(500).json({ error: err.message || String(err) });
  }
});

// POST /api/verifications/:userId/approve — grant the Verified badge.
app.post('/api/verifications/:userId/approve', async (req, res) => {
  try {
    const { userId } = req.params;
    const { data, error } = await supabase.rpc('approve_provider_verification', {
      p_user_id: userId,
      p_reviewer: null,
    });
    if (error) throw error;
    res.json({ ok: true, verification: data });
  } catch (err) {
    console.error('POST approve verification failed:', err.message || err);
    res.status(400).json({ error: err.message || String(err) });
  }
});

// POST /api/verifications/:userId/reject — Body: { reason? }.
app.post('/api/verifications/:userId/reject', async (req, res) => {
  try {
    const { userId } = req.params;
    const { reason } = req.body || {};
    const { data, error } = await supabase.rpc('reject_provider_verification', {
      p_user_id: userId,
      p_reason: reason || null,
      p_reviewer: null,
    });
    if (error) throw error;
    res.json({ ok: true, verification: data });
  } catch (err) {
    console.error('POST reject verification failed:', err.message || err);
    res.status(400).json({ error: err.message || String(err) });
  }
});

app.listen(PORT, () => {
  console.log(`\n  KajHobe admin payout panel running at http://localhost:${PORT}\n  (localhost only — holds the service role key; do not expose)\n`);
});
