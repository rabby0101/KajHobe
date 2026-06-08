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

app.listen(PORT, () => {
  console.log(`\n  KajHobe admin payout panel running at http://localhost:${PORT}\n  (localhost only — holds the service role key; do not expose)\n`);
});
