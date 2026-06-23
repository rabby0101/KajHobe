import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { User, MapPin, Phone, Mail, Edit, Save, Briefcase, BadgeCheck, Clock, XOctagon } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/integrations/supabase/client';
import { toast } from '@/hooks/use-toast';
import Header from '@/components/Header';
import PayoutAccountForm from '@/components/payments/PayoutAccountForm';
import VerifiedBadge from '@/components/VerifiedBadge';
import ProviderVerificationDialog from '@/components/ProviderVerificationDialog';

interface Profile {
  id: string;
  full_name: string | null;
  email: string | null;
  phone: string | null;
  location: string | null;
  avatar_url: string | null;
  user_type: string | null; // Changed from literal union to string to match database
  is_verified_provider?: boolean | null;
}

interface Verification {
  status: string;
  nid_number?: string | null;
  phone?: string | null;
  phone_verified?: boolean | null;
  demo_video_urls?: string[] | null;
  rejection_reason?: string | null;
}

const Profile = () => {
  const { user } = useAuth();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [verification, setVerification] = useState<Verification | null>(null);
  const [showVerifyDialog, setShowVerifyDialog] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (user) {
      fetchProfile();
      fetchVerification();
    }
  }, [user]);

  const fetchProfile = async () => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user?.id)
        .single();

      if (error) throw error;
      setProfile(data);
    } catch (error) {
      console.error('Error fetching profile:', error);
      toast({
        title: "Error",
        description: "Failed to load profile",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const fetchVerification = async () => {
    try {
      const { data } = await supabase
        .from('provider_verifications' as any)
        .select('status, nid_number, phone, phone_verified, demo_video_urls, rejection_reason')
        .eq('user_id', user?.id)
        .maybeSingle();
      setVerification((data as Verification) ?? null);
    } catch (error) {
      // table may not exist yet in some environments — non-fatal
      console.warn('verification fetch skipped:', error);
    }
  };

  const accountPhoneLocal = (): string | null => {
    const raw = (user as any)?.phone as string | undefined;
    if (!raw) return null;
    return raw.startsWith('880') ? '0' + raw.slice(3) : raw;
  };

  const updateProfile = async () => {
    if (!profile || !user) return;

    try {
      const { error } = await supabase
        .from('profiles')
        .update({
          full_name: profile.full_name,
          phone: profile.phone,
          location: profile.location,
          user_type: profile.user_type,
        })
        .eq('id', user.id);

      if (error) throw error;

      toast({
        title: "Success",
        description: "Profile updated successfully",
      });
      setIsEditing(false);
    } catch (error) {
      console.error('Error updating profile:', error);
      toast({
        title: "Error",
        description: "Failed to update profile",
        variant: "destructive",
      });
    }
  };

  const isServiceProvider = profile?.user_type === 'provider' || profile?.user_type === 'both';

  if (loading) {
    return (
      <div className="min-h-screen bg-background">
        <Header />
        <div className="container mx-auto px-4 py-8">
          <div className="text-center">Loading profile...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <Header />
      <div className="container mx-auto px-4 py-8">
        <div className="max-w-4xl mx-auto">
          <div className="flex justify-between items-center mb-8">
            <h1 className="text-3xl font-bold text-foreground">Profile</h1>
            <Button
              onClick={() => isEditing ? updateProfile() : setIsEditing(true)}
              className="flex items-center gap-2"
            >
              {isEditing ? <Save className="h-4 w-4" /> : <Edit className="h-4 w-4" />}
              {isEditing ? 'Save Changes' : 'Edit Profile'}
            </Button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {/* Profile Info Card */}
            <Card className="md:col-span-2">
              <CardHeader>
                <CardTitle>Personal Information</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center space-x-4">
                  <Avatar className="h-20 w-20">
                    <AvatarImage src={profile?.avatar_url || ''} />
                    <AvatarFallback>
                      <User className="h-8 w-8" />
                    </AvatarFallback>
                  </Avatar>
                  <div>
                    <h3 className="text-xl font-semibold">{profile?.full_name || 'Anonymous User'}</h3>
                    <div className="flex gap-2 mt-1">
                      <Badge variant="secondary">{profile?.user_type || 'seeker'}</Badge>
                      {profile?.is_verified_provider && <VerifiedBadge />}
                      {isServiceProvider && !profile?.is_verified_provider && (
                        <Badge variant="default" className="bg-blue-500">
                          <Briefcase className="h-3 w-3 mr-1" />
                          Service Provider
                        </Badge>
                      )}
                    </div>
                  </div>
                </div>

                {/* Provider verification status / call-to-action */}
                <div className="p-4 border rounded-lg">
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

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <Label htmlFor="full_name">Full Name</Label>
                    <Input
                      id="full_name"
                      value={profile?.full_name || ''}
                      onChange={(e) => setProfile(prev => prev ? { ...prev, full_name: e.target.value } : null)}
                      disabled={!isEditing}
                    />
                  </div>
                  <div>
                    <Label htmlFor="email">Email</Label>
                    <Input
                      id="email"
                      value={profile?.email || ''}
                      disabled
                      className="bg-muted"
                    />
                  </div>
                  <div>
                    <Label htmlFor="phone">Phone</Label>
                    <Input
                      id="phone"
                      value={profile?.phone || ''}
                      onChange={(e) => setProfile(prev => prev ? { ...prev, phone: e.target.value } : null)}
                      disabled={!isEditing}
                    />
                  </div>
                  <div>
                    <Label htmlFor="location">Location</Label>
                    <Input
                      id="location"
                      value={profile?.location || ''}
                      onChange={(e) => setProfile(prev => prev ? { ...prev, location: e.target.value } : null)}
                      disabled={!isEditing}
                    />
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Stats Card */}
            <Card>
              <CardHeader>
                <CardTitle>Activity</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Jobs Posted</span>
                    <span className="font-semibold">0</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Jobs Completed</span>
                    <span className="font-semibold">0</span>
                  </div>
                  {isServiceProvider && (
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Proposals Sent</span>
                      <span className="font-semibold">0</span>
                    </div>
                  )}
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Rating</span>
                    <span className="font-semibold">⭐ N/A</span>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {isServiceProvider && (
            <div className="mt-6">
              <PayoutAccountForm />
            </div>
          )}
        </div>
      </div>

      {user && (
        <ProviderVerificationDialog
          open={showVerifyDialog}
          onOpenChange={setShowVerifyDialog}
          userId={user.id}
          existing={verification}
          accountPhone={accountPhoneLocal()}
          onSubmitted={() => { fetchVerification(); fetchProfile(); }}
        />
      )}
    </div>
  );
};

export default Profile;
