import React, { useEffect, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Briefcase, BadgeCheck, Clock, XOctagon } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/integrations/supabase/client';
import ProviderVerificationDialog from '@/components/ProviderVerificationDialog';

interface Verification {
  status: string;
  nid_number?: string | null;
  phone?: string | null;
  phone_verified?: boolean | null;
  demo_video_urls?: string[] | null;
  rejection_reason?: string | null;
}

interface Props {
  /** compact = small inline card for Index/Dashboard, full = same but always visible in Profile settings */
  variant?: 'compact' | 'full';
  className?: string;
  /** Open the verification dialog immediately once loaded (e.g. deep-linked from the welcome modal). */
  autoOpen?: boolean;
}

/**
 * Shows a provider's verification state (not started / pending / rejected / verified)
 * and owns the ProviderVerificationDialog. Hidden entirely for users who aren't
 * providers/both and are already verified — i.e. nothing left to nudge.
 */
export default function ProviderVerificationBanner({ variant = 'compact', className, autoOpen }: Props) {
  const { user } = useAuth();
  const [profile, setProfile] = useState<{ user_type: string | null; is_verified_provider?: boolean | null } | null>(null);
  const [verification, setVerification] = useState<Verification | null>(null);
  const [showVerifyDialog, setShowVerifyDialog] = useState(false);
  const [loaded, setLoaded] = useState(false);

  const fetchProfile = async () => {
    if (!user) return;
    const { data } = await supabase
      .from('profiles')
      .select('user_type, is_verified_provider')
      .eq('id', user.id)
      .single();
    setProfile((data as any) ?? null);
  };

  const fetchVerification = async () => {
    if (!user) return;
    const { data } = await supabase
      .from('provider_verifications' as any)
      .select('status, nid_number, phone, phone_verified, demo_video_urls, rejection_reason')
      .eq('user_id', user.id)
      .maybeSingle();
    setVerification((data as Verification) ?? null);
  };

  useEffect(() => {
    if (!user) return;
    Promise.all([fetchProfile(), fetchVerification()]).finally(() => setLoaded(true));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]);

  useEffect(() => {
    if (!autoOpen || !loaded || !profile) return;
    if (!profile.is_verified_provider && verification?.status !== 'pending') {
      setShowVerifyDialog(true);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [autoOpen, loaded]);

  const accountPhoneLocal = (): string | null => {
    const raw = (user as any)?.phone as string | undefined;
    if (!raw) return null;
    return raw.startsWith('880') ? '0' + raw.slice(3) : raw;
  };

  const isProviderIntent = profile?.user_type === 'provider' || profile?.user_type === 'both';

  // Nothing to show until loaded. The compact nudge (Index/Dashboard) only shows for
  // users who've expressed provider intent and aren't verified yet; the full variant
  // (Profile settings) is always visible so any seeker can discover "become a provider".
  if (!user || !loaded) return null;
  if (variant === 'compact' && (!isProviderIntent || profile?.is_verified_provider)) return null;

  return (
    <>
      <div className={`p-4 border rounded-lg ${className ?? ''}`}>
        {profile?.is_verified_provider ? (
          <div className="flex items-center gap-3">
            <BadgeCheck className="h-5 w-5 text-blue-500" />
            <div>
              <p className="text-sm font-medium">Verified Service Provider</p>
              <p className="text-xs text-muted-foreground">Verified by KajHobe.</p>
            </div>
          </div>
        ) : verification?.status === 'pending' ? (
          <div className="flex items-center gap-3">
            <Clock className="h-5 w-5 text-amber-500" />
            <div>
              <p className="text-sm font-medium">Verification pending</p>
              <p className="text-xs text-muted-foreground">
                Your application is under review. We'll notify you once it's approved.
              </p>
            </div>
          </div>
        ) : verification?.status === 'rejected' ? (
          <div className="space-y-2">
            <div className="flex items-center gap-3">
              <XOctagon className="h-5 w-5 text-red-500" />
              <div>
                <p className="text-sm font-medium text-red-600">Verification rejected</p>
                {verification.rejection_reason && (
                  <p className="text-xs text-muted-foreground">{verification.rejection_reason}</p>
                )}
              </div>
            </div>
            <Button size="sm" onClick={() => setShowVerifyDialog(true)}>Reapply</Button>
          </div>
        ) : (
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <Briefcase className="h-5 w-5 text-blue-500" />
              <div>
                <p className="text-sm font-medium">Become a Service Provider</p>
                <p className="text-xs text-muted-foreground">
                  Get verified to send proposals and offer services.
                </p>
              </div>
            </div>
            <Button size="sm" onClick={() => setShowVerifyDialog(true)}>Get Verified</Button>
          </div>
        )}
      </div>

      <ProviderVerificationDialog
        open={showVerifyDialog}
        onOpenChange={setShowVerifyDialog}
        userId={user.id}
        existing={verification}
        accountPhone={accountPhoneLocal()}
        onSubmitted={() => { fetchVerification(); fetchProfile(); }}
      />
    </>
  );
}
