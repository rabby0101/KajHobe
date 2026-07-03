import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Briefcase, ClipboardList, Sparkles } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/integrations/supabase/client';
import { useOnboarding } from '@/hooks/useOnboarding';

type Intent = 'seeker' | 'provider' | 'both';

const OPTIONS: { value: Intent; label: string; description: string; icon: React.ReactNode }[] = [
  {
    value: 'seeker',
    label: 'I want to post a job',
    description: 'Find a trusted local provider for something I need done.',
    icon: <ClipboardList className="h-6 w-6" />,
  },
  {
    value: 'provider',
    label: 'I want to offer my services',
    description: 'Get verified and start receiving job requests.',
    icon: <Briefcase className="h-6 w-6" />,
  },
  {
    value: 'both',
    label: 'Both',
    description: 'Post jobs sometimes, offer my own services other times.',
    icon: <Sparkles className="h-6 w-6" />,
  },
];

/** One-time post-signup modal that captures role intent and routes the user toward their first action. */
export default function WelcomeModal() {
  const { user } = useAuth();
  const { needsWelcome, markWelcomed } = useOnboarding();
  const navigate = useNavigate();
  const [submitting, setSubmitting] = useState(false);

  if (!needsWelcome) return null;

  const choose = async (intent: Intent) => {
    if (!user || submitting) return;
    setSubmitting(true);
    try {
      await supabase.from('profiles').update({ user_type: intent }).eq('id', user.id);
      await markWelcomed();
      if (intent === 'provider' || intent === 'both') {
        navigate('/profile?verify=1');
      } else {
        navigate('/post-job');
      }
    } finally {
      setSubmitting(false);
    }
  };

  const skip = async () => {
    if (submitting) return;
    await markWelcomed();
  };

  return (
    <Dialog open onOpenChange={() => { /* not dismissable by backdrop/escape */ }}>
      <DialogContent className="sm:max-w-md" onInteractOutside={(e) => e.preventDefault()}>
        <DialogHeader>
          <DialogTitle>What brings you to KajHobe?</DialogTitle>
          <DialogDescription>
            Pick what you're here for — you can always do the other one later too.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-3 py-2">
          {OPTIONS.map((opt) => (
            <button
              key={opt.value}
              disabled={submitting}
              onClick={() => choose(opt.value)}
              className="w-full flex items-center gap-3 p-4 border rounded-lg text-left hover:border-primary hover:bg-accent transition-colors disabled:opacity-50"
            >
              <div className="text-primary">{opt.icon}</div>
              <div>
                <p className="text-sm font-medium">{opt.label}</p>
                <p className="text-xs text-muted-foreground">{opt.description}</p>
              </div>
            </button>
          ))}
        </div>
        <DialogFooter>
          <Button variant="ghost" size="sm" disabled={submitting} onClick={skip}>
            Skip for now
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
