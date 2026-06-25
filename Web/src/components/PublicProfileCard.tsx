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
