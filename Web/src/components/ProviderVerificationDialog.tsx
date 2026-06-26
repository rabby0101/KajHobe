import React, { useState } from 'react';
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { BadgeCheck, Plus, X, Play } from 'lucide-react';
import { supabase } from '@/integrations/supabase/client';
import { toast } from '@/hooks/use-toast';

interface ExistingVerification {
  nid_number?: string | null;
  phone?: string | null;
  phone_verified?: boolean | null;
  demo_video_urls?: string[] | null;
}

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  userId: string;
  existing?: ExistingVerification | null;
  /** Phone already on the auth account (verified), in 01… form, if any. */
  accountPhone?: string | null;
  onSubmitted: () => void;
}

export default function ProviderVerificationDialog({
  open, onOpenChange, userId, existing, accountPhone, onSubmitted,
}: Props) {
  const [nidNumber, setNidNumber] = useState(existing?.nid_number ?? '');
  const [nidFront, setNidFront] = useState<File | null>(null);
  const [nidBack, setNidBack] = useState<File | null>(null);
  const [certs, setCerts] = useState<File[]>([]);
  const [demoUrls, setDemoUrls] = useState<string[]>(existing?.demo_video_urls ?? []);
  const [demoInput, setDemoInput] = useState('');

  const [phone, setPhone] = useState(accountPhone ?? existing?.phone ?? '');
  const [submitting, setSubmitting] = useState(false);

  // Phone is optional contact info now (phone OTP is postponed). Treated as
  // verified only if it came from the account's signup phone.
  const phoneVerified = Boolean(accountPhone) || existing?.phone_verified === true;
  const canSubmit = nidNumber.trim() !== '' && !!nidFront && !submitting;

  const addDemo = () => {
    const t = demoInput.trim();
    if (t) { setDemoUrls((u) => [...u, t]); setDemoInput(''); }
  };

  const uploadDoc = async (bucket: string, file: File, name: string) => {
    const ext = file.name.split('.').pop() || 'jpg';
    const path = `${userId}/${name}-${Date.now()}.${ext}`;
    const { error } = await supabase.storage.from(bucket).upload(path, file, { upsert: true });
    if (error) throw error;
    return path;
  };

  const submit = async () => {
    // Phone is optional: send NULL when blank so the BD-format CHECK constraint
    // (phone IS NULL OR phone ~ '^01[0-9]{9}$') passes. An empty string fails it.
    const trimmedPhone = phone.trim();
    if (trimmedPhone !== '' && !/^01[0-9]{9}$/.test(trimmedPhone)) {
      toast({
        title: 'Invalid phone number',
        description: 'Enter an 11-digit Bangladeshi mobile number like 01XXXXXXXXX, or leave it blank.',
        variant: 'destructive',
      });
      return;
    }

    setSubmitting(true);
    try {
      const frontPath = nidFront ? await uploadDoc('provider-nid', nidFront, 'nid-front') : null;
      const backPath = nidBack ? await uploadDoc('provider-nid', nidBack, 'nid-back') : null;
      const certPaths: string[] = [];
      for (let i = 0; i < certs.length; i++) {
        certPaths.push(await uploadDoc('provider-certificates', certs[i], `cert-${i}`));
      }

      const { error } = await supabase
        .from('provider_verifications' as any)
        .upsert({
          user_id: userId,
          status: 'pending',
          nid_number: nidNumber.trim(),
          nid_front_path: frontPath,
          nid_back_path: backPath,
          phone: trimmedPhone === '' ? null : trimmedPhone,
          phone_verified: phoneVerified,
          certificate_paths: certPaths,
          demo_video_urls: demoUrls,
          submitted_at: new Date().toISOString(),
        }, { onConflict: 'user_id' });
      if (error) throw error;

      toast({ title: 'Submitted for review', description: 'We will notify you once approved.' });
      onSubmitted();
      onOpenChange(false);
    } catch (e: any) {
      toast({ title: 'Submission failed', description: e.message, variant: 'destructive' });
    } finally { setSubmitting(false); }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-lg">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <BadgeCheck className="h-5 w-5 text-blue-500" /> Become a Verified Provider
          </DialogTitle>
          <DialogDescription>
            Submit your NID, a verified phone, and optionally certificates and work-demo
            videos. Our team reviews every application manually.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-5">
          {/* NID */}
          <div className="space-y-2">
            <Label>National ID (NID) number</Label>
            <Input value={nidNumber} onChange={(e) => setNidNumber(e.target.value)} placeholder="NID number" />
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label className="text-xs text-muted-foreground">NID front photo</Label>
                <Input type="file" accept="image/*" onChange={(e) => setNidFront(e.target.files?.[0] ?? null)} />
              </div>
              <div>
                <Label className="text-xs text-muted-foreground">NID back photo</Label>
                <Input type="file" accept="image/*" onChange={(e) => setNidBack(e.target.files?.[0] ?? null)} />
              </div>
            </div>
          </div>

          {/* Phone (optional contact) */}
          <div className="space-y-2">
            <Label>Phone (optional)</Label>
            <Input
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="01XXXXXXXXX"
            />
          </div>

          {/* Certificates */}
          <div className="space-y-2">
            <Label>Certificates (optional)</Label>
            <Input type="file" accept="image/*,application/pdf" multiple
              onChange={(e) => setCerts(Array.from(e.target.files ?? []))} />
            {certs.length > 0 && (
              <p className="text-xs text-muted-foreground">{certs.length} file(s) selected</p>
            )}
          </div>

          {/* Work demos */}
          <div className="space-y-2">
            <Label>Work demos (optional)</Label>
            <p className="text-xs text-muted-foreground">Paste YouTube, Facebook, or Drive links showing your work.</p>
            {demoUrls.map((u, i) => (
              <div key={i} className="flex items-center gap-2 text-sm">
                <Play className="h-4 w-4 text-red-500" />
                <span className="flex-1 truncate">{u}</span>
                <Button type="button" size="icon" variant="ghost"
                  onClick={() => setDemoUrls((arr) => arr.filter((_, idx) => idx !== i))}>
                  <X className="h-4 w-4" />
                </Button>
              </div>
            ))}
            <div className="flex items-center gap-2">
              <Input value={demoInput} onChange={(e) => setDemoInput(e.target.value)}
                placeholder="https://youtube.com/..." onKeyDown={(e) => e.key === 'Enter' && (e.preventDefault(), addDemo())} />
              <Button type="button" variant="outline" size="icon" onClick={addDemo} disabled={!demoInput.trim()}>
                <Plus className="h-4 w-4" />
              </Button>
            </div>
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Cancel</Button>
          <Button onClick={submit} disabled={!canSubmit}>
            {submitting ? 'Submitting…' : 'Submit for review'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
