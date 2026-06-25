# Foundation + W1 (Public Profiles & Trust Levels) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Regenerate the web Supabase types to match the live DB, then add public-provider profiles with 5-tier trust badges (a hook, a TrustBadge, a PublicProfileCard, and a `/provider/:id` page).

**Architecture:** Mirror the iOS `PublicProfileNetworking` + `PublicProfileComponents` against the existing `public_profiles` materialized table. Follow the existing web patterns: TanStack Query hooks importing `supabase` from `@/integrations/supabase/client`, shadcn UI, `Header` + container page layout, react-router routes registered in `App.tsx`.

**Tech Stack:** React 18, Vite, TypeScript, shadcn/ui, Tailwind, TanStack Query, react-router-dom v6, `@supabase/supabase-js`.

---

## File structure

- Modify: `Web/src/integrations/supabase/types.ts` — regenerated from live DB (adds `public_profiles`, escrow tables, etc.).
- Create: `Web/src/lib/trustLevel.ts` — pure trust-tier helpers (enum, labels, colors, icons, derivation).
- Create: `Web/src/hooks/usePublicProfile.ts` — fetch one profile + batch summaries.
- Create: `Web/src/components/TrustBadge.tsx` — color-coded 5-tier badge.
- Create: `Web/src/components/PublicProfileCard.tsx` — compact profile card.
- Create: `Web/src/pages/PublicProfile.tsx` — full `/provider/:id` page.
- Modify: `Web/src/App.tsx` — register `/provider/:id` route.

All commands below run from the `Web/` directory unless noted.

---

### Task 0: Regenerate Supabase types (foundation for all workstreams)

**Files:**
- Modify: `Web/src/integrations/supabase/types.ts`

- [ ] **Step 1: Generate fresh types from the live project**

Use the Supabase MCP tool `generate_typescript_types` with `project_id: xatlqnbrvgukuqewsxux`. Write the returned TypeScript verbatim into `Web/src/integrations/supabase/types.ts`, replacing the file contents. Keep the leading auto-generated comment.

- [ ] **Step 2: Verify the new tables are present**

Run: `grep -nE "public_profiles:|escrow_transactions:|provider_payout_accounts:|deal_disputes:|job_interests:|deal_offers:|completion_requests:" src/integrations/supabase/types.ts`
Expected: a line for each of those tables.

- [ ] **Step 3: Type-check the project compiles against the new types**

Run: `npx tsc --noEmit`
Expected: no new errors introduced by the type regen (pre-existing errors, if any, are unchanged). If the regen surfaces errors in existing files because a column was renamed/removed, note them — they are pre-existing drift, fix only if trivial and in scope.

- [ ] **Step 4: Commit**

```bash
git add src/integrations/supabase/types.ts
git commit -m "chore(web): regenerate Supabase types from live DB"
```

---

### Task 1: Trust-level helpers (pure logic)

**Files:**
- Create: `Web/src/lib/trustLevel.ts`

- [ ] **Step 1: Write the helper module**

```ts
// Mirrors the iOS TrustLevel enum + DashboardAnalytics.trustLevel thresholds.
export type TrustLevel =
  | 'unverified'
  | 'newcomer'
  | 'established'
  | 'experienced'
  | 'expert';

export interface TrustLevelMeta {
  label: string;
  /** Tailwind classes for the badge (bg + text). */
  className: string;
  /** lucide-react icon name used by TrustBadge. */
  icon: 'HelpCircle' | 'User' | 'BadgeCheck' | 'Star' | 'Crown';
}

export const TRUST_LEVEL_META: Record<TrustLevel, TrustLevelMeta> = {
  unverified:  { label: 'Unverified',  className: 'bg-gray-100 text-gray-700',     icon: 'HelpCircle' },
  newcomer:    { label: 'Newcomer',    className: 'bg-blue-100 text-blue-700',     icon: 'User' },
  established: { label: 'Established',  className: 'bg-green-100 text-green-700',   icon: 'BadgeCheck' },
  experienced: { label: 'Experienced', className: 'bg-orange-100 text-orange-700', icon: 'Star' },
  expert:      { label: 'Expert',      className: 'bg-purple-100 text-purple-700', icon: 'Crown' },
};

/** Mirrors iOS DashboardAnalytics.trustLevel(completedJobs:avgRating:). */
export function deriveTrustLevel(completedJobs: number, avgRating: number): TrustLevel {
  if (completedJobs >= 20 && avgRating >= 4.5) return 'expert';
  if (completedJobs >= 10 && avgRating >= 4.0) return 'experienced';
  if (completedJobs >= 5 && avgRating >= 3.5) return 'established';
  if (completedJobs >= 1) return 'newcomer';
  return 'unverified';
}

/** Normalizes a server trust_level string to a known tier (fallback: unverified). */
export function normalizeTrustLevel(raw: string | null | undefined): TrustLevel {
  if (raw && raw in TRUST_LEVEL_META) return raw as TrustLevel;
  return 'unverified';
}
```

- [ ] **Step 2: Type-check**

Run: `npx tsc --noEmit`
Expected: PASS (no new errors).

- [ ] **Step 3: Commit**

```bash
git add src/lib/trustLevel.ts
git commit -m "feat(web): add trust-level helpers (parity with iOS TrustLevel)"
```

---

### Task 2: usePublicProfile hook

**Files:**
- Create: `Web/src/hooks/usePublicProfile.ts`

- [ ] **Step 1: Write the hook**

```ts
import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';

// Shape of a row in the materialized public_profiles table (iOS PublicProfile).
export interface PublicProfile {
  id: string;
  full_name: string | null;
  avatar_url: string | null;
  bio: string | null;
  location: string | null;
  website: string | null;
  is_service_provider: boolean | null;
  completed_jobs: number;
  avg_job_value: number;
  total_earnings: number;
  avg_rating: number;
  review_count: number;
  is_online: boolean | null;
  last_seen_at: string | null;
  average_response_time_minutes: number | null;
  service_categories: string[];
  trust_level: string;
  last_updated: string | null;
}

const COLUMNS =
  'id, full_name, avatar_url, bio, location, website, is_service_provider, ' +
  'completed_jobs, avg_job_value, total_earnings, avg_rating, review_count, ' +
  'is_online, last_seen_at, average_response_time_minutes, service_categories, ' +
  'trust_level, last_updated';

function normalizeRow(row: any): PublicProfile {
  return {
    ...row,
    completed_jobs: row.completed_jobs ?? 0,
    avg_job_value: Number(row.avg_job_value ?? 0),
    total_earnings: Number(row.total_earnings ?? 0),
    avg_rating: Number(row.avg_rating ?? 0),
    review_count: row.review_count ?? 0,
    service_categories: Array.isArray(row.service_categories) ? row.service_categories : [],
    trust_level: row.trust_level ?? 'unverified',
  } as PublicProfile;
}

/** One provider's public profile, or null if none exists yet. */
export const usePublicProfile = (providerId: string | undefined) =>
  useQuery({
    queryKey: ['public-profile', providerId],
    queryFn: async (): Promise<PublicProfile | null> => {
      if (!providerId) return null;
      const { data, error } = await supabase
        .from('public_profiles')
        .select(COLUMNS)
        .eq('id', providerId)
        .maybeSingle();
      if (error) {
        console.error('Error fetching public profile:', error);
        throw error;
      }
      return data ? normalizeRow(data) : null;
    },
    enabled: !!providerId,
    staleTime: 60000,
  });

/** Batch summaries keyed by id, for lists/notifications. */
export const usePublicProfileSummaries = (providerIds: string[]) =>
  useQuery({
    queryKey: ['public-profile-summaries', [...providerIds].sort()],
    queryFn: async (): Promise<Record<string, PublicProfile>> => {
      if (providerIds.length === 0) return {};
      const { data, error } = await supabase
        .from('public_profiles')
        .select(COLUMNS)
        .in('id', providerIds);
      if (error) {
        console.error('Error fetching public profile summaries:', error);
        throw error;
      }
      const map: Record<string, PublicProfile> = {};
      for (const row of data ?? []) map[(row as any).id] = normalizeRow(row);
      return map;
    },
    enabled: providerIds.length > 0,
    staleTime: 60000,
  });
```

- [ ] **Step 2: Type-check**

Run: `npx tsc --noEmit`
Expected: PASS. If `supabase.from('public_profiles')` errors, Task 0 did not regenerate types correctly — go back and fix Task 0.

- [ ] **Step 3: Commit**

```bash
git add src/hooks/usePublicProfile.ts
git commit -m "feat(web): add usePublicProfile hook (single + batch)"
```

---

### Task 3: TrustBadge component

**Files:**
- Create: `Web/src/components/TrustBadge.tsx`

- [ ] **Step 1: Write the component**

```tsx
import { HelpCircle, User, BadgeCheck, Star, Crown } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';
import { TRUST_LEVEL_META, normalizeTrustLevel } from '@/lib/trustLevel';

const ICONS = { HelpCircle, User, BadgeCheck, Star, Crown } as const;

interface TrustBadgeProps {
  trustLevel: string | null | undefined;
  compact?: boolean;
  className?: string;
}

export default function TrustBadge({ trustLevel, compact = false, className }: TrustBadgeProps) {
  const level = normalizeTrustLevel(trustLevel);
  const meta = TRUST_LEVEL_META[level];
  const Icon = ICONS[meta.icon];
  return (
    <Badge variant="secondary" className={cn(meta.className, 'gap-1 border-0', className)}>
      <Icon className="h-3 w-3" />
      {!compact && <span>{meta.label}</span>}
    </Badge>
  );
}
```

- [ ] **Step 2: Type-check**

Run: `npx tsc --noEmit`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add src/components/TrustBadge.tsx
git commit -m "feat(web): add TrustBadge component"
```

---

### Task 4: PublicProfileCard component

**Files:**
- Create: `Web/src/components/PublicProfileCard.tsx`

- [ ] **Step 1: Write the component**

```tsx
import { useNavigate } from 'react-router-dom';
import { Star, Briefcase, MapPin } from 'lucide-react';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Card, CardContent } from '@/components/ui/card';
import TrustBadge from '@/components/TrustBadge';
import type { PublicProfile } from '@/hooks/usePublicProfile';

interface PublicProfileCardProps {
  profile: PublicProfile;
  /** When true, clicking navigates to the full /provider/:id page. */
  linkToProfile?: boolean;
}

export default function PublicProfileCard({ profile, linkToProfile = true }: PublicProfileCardProps) {
  const navigate = useNavigate();
  const initials = (profile.full_name ?? 'U').slice(0, 1).toUpperCase();
  const rating = profile.review_count > 0 ? profile.avg_rating.toFixed(1) : 'No ratings';

  return (
    <Card
      className={linkToProfile ? 'cursor-pointer hover:bg-accent/50 transition-colors' : ''}
      onClick={linkToProfile ? () => navigate(`/provider/${profile.id}`) : undefined}
    >
      <CardContent className="flex items-center gap-3 p-4">
        <div className="relative">
          <Avatar className="h-12 w-12">
            <AvatarImage src={profile.avatar_url ?? ''} />
            <AvatarFallback>{initials}</AvatarFallback>
          </Avatar>
          {profile.is_online && (
            <span className="absolute bottom-0 right-0 h-3 w-3 rounded-full bg-green-500 ring-2 ring-background" />
          )}
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <span className="truncate font-semibold">{profile.full_name ?? 'Anonymous'}</span>
            <TrustBadge trustLevel={profile.trust_level} compact />
          </div>
          <div className="mt-1 flex items-center gap-3 text-sm text-muted-foreground">
            <span className="flex items-center gap-1">
              <Star className="h-3.5 w-3.5" /> {rating}
            </span>
            <span className="flex items-center gap-1">
              <Briefcase className="h-3.5 w-3.5" /> {profile.completed_jobs} jobs
            </span>
            {profile.location && (
              <span className="flex items-center gap-1 truncate">
                <MapPin className="h-3.5 w-3.5" /> {profile.location}
              </span>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
```

- [ ] **Step 2: Type-check**

Run: `npx tsc --noEmit`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add src/components/PublicProfileCard.tsx
git commit -m "feat(web): add PublicProfileCard component"
```

---

### Task 5: PublicProfile page + route

**Files:**
- Create: `Web/src/pages/PublicProfile.tsx`
- Modify: `Web/src/App.tsx`

- [ ] **Step 1: Write the page**

```tsx
import { useParams } from 'react-router-dom';
import { Star, Briefcase, Wallet, Clock } from 'lucide-react';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import Header from '@/components/Header';
import TrustBadge from '@/components/TrustBadge';
import { usePublicProfile } from '@/hooks/usePublicProfile';

function StatTile({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <Card>
      <CardContent className="flex flex-col items-center gap-1 p-4 text-center">
        <div className="text-muted-foreground">{icon}</div>
        <div className="text-xl font-bold">{value}</div>
        <div className="text-xs text-muted-foreground">{label}</div>
      </CardContent>
    </Card>
  );
}

export default function PublicProfile() {
  const { id } = useParams<{ id: string }>();
  const { data: profile, isLoading } = usePublicProfile(id);

  return (
    <div className="min-h-screen bg-background">
      <Header />
      <div className="container mx-auto px-4 py-8">
        {isLoading ? (
          <div className="text-center text-muted-foreground">Loading profile…</div>
        ) : !profile ? (
          <div className="text-center text-muted-foreground">Profile not found.</div>
        ) : (
          <div className="mx-auto max-w-3xl space-y-6">
            {/* Hero */}
            <div className="flex items-center gap-4">
              <div className="relative">
                <Avatar className="h-20 w-20">
                  <AvatarImage src={profile.avatar_url ?? ''} />
                  <AvatarFallback>{(profile.full_name ?? 'U').slice(0, 1).toUpperCase()}</AvatarFallback>
                </Avatar>
                {profile.is_online && (
                  <span className="absolute bottom-1 right-1 h-3.5 w-3.5 rounded-full bg-green-500 ring-2 ring-background" />
                )}
              </div>
              <div>
                <h1 className="text-2xl font-bold">{profile.full_name ?? 'Anonymous'}</h1>
                <div className="mt-1 flex items-center gap-2">
                  <TrustBadge trustLevel={profile.trust_level} />
                  {profile.location && <span className="text-sm text-muted-foreground">{profile.location}</span>}
                </div>
              </div>
            </div>

            {/* Stats */}
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              <StatTile icon={<Briefcase className="h-5 w-5" />} label="Completed jobs" value={String(profile.completed_jobs)} />
              <StatTile icon={<Star className="h-5 w-5" />} label="Avg rating" value={profile.review_count > 0 ? profile.avg_rating.toFixed(1) : '—'} />
              <StatTile icon={<Wallet className="h-5 w-5" />} label="Total earnings" value={`৳${Math.round(profile.total_earnings).toLocaleString()}`} />
              <StatTile icon={<Clock className="h-5 w-5" />} label="Resp. time" value={profile.average_response_time_minutes != null ? `${profile.average_response_time_minutes}m` : '—'} />
            </div>

            {/* Bio */}
            {profile.bio && (
              <Card>
                <CardHeader><CardTitle>About</CardTitle></CardHeader>
                <CardContent className="text-sm text-muted-foreground">{profile.bio}</CardContent>
              </Card>
            )}

            {/* Service categories */}
            {profile.service_categories.length > 0 && (
              <Card>
                <CardHeader><CardTitle>Services</CardTitle></CardHeader>
                <CardContent className="flex flex-wrap gap-2">
                  {profile.service_categories.map((c) => (
                    <Badge key={c} variant="secondary">{c}</Badge>
                  ))}
                </CardContent>
              </Card>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Register the route in `App.tsx`**

Add the import alongside the other page imports:

```tsx
import PublicProfile from "./pages/PublicProfile";
```

Add the route inside `<Routes>`, immediately after the `/profile` route:

```tsx
<Route path="/provider/:id" element={<PublicProfile />} />
```

- [ ] **Step 3: Type-check**

Run: `npx tsc --noEmit`
Expected: PASS.

- [ ] **Step 4: Lint**

Run: `npm run lint`
Expected: no new errors in the files created/modified by this plan.

- [ ] **Step 5: Manual verification**

Run: `npm run dev`, then open `/provider/<a real provider id>` (use an id from the `public_profiles` table — there are 3 rows). Confirm: hero with avatar + trust badge, four stat tiles, bio and services render; online dot appears when `is_online`. A non-existent id shows "Profile not found."

- [ ] **Step 6: Commit**

```bash
git add src/pages/PublicProfile.tsx src/App.tsx
git commit -m "feat(web): add /provider/:id public profile page"
```

---

## Self-review notes

- **Spec coverage (W1):** trust tiers + derivation (Task 1), data access (Task 2), TrustBadge (Task 3), PublicProfileCard (Task 4), `/provider/:id` page (Task 5). Embedding the card in interest-request notifications is deferred to **W6 (enhanced notifications)**, where the notification card is rebuilt — noted there to avoid double work.
- **Foundation:** Task 0 (type regen) unblocks every later workstream, not just W1.
- **Testing adaptation:** the web app has no test runner. W1 is data + UI, verified via `tsc --noEmit` + `npm run lint` + manual flow. `vitest` will be introduced in W3/W5 for the pure aggregation/cooldown logic where unit tests carry real value.
- **Type names:** `PublicProfile` (hook), `TrustLevel`/`TRUST_LEVEL_META`/`deriveTrustLevel`/`normalizeTrustLevel` (lib) are referenced consistently across Tasks 2–5.
