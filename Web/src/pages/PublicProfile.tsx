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
