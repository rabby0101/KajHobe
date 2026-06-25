import { useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';

/** How often to refresh presence while the tab is visible (ms). Matches iOS (5 min). */
const HEARTBEAT_MS = 300_000;

async function writePresence(userId: string, isOnline: boolean) {
  const { error } = await supabase
    .from('profiles')
    .update({ is_online: isOnline, last_seen_at: new Date().toISOString() })
    .eq('id', userId);
  if (error) console.error('Presence update failed:', error);
}

/**
 * Maintains the signed-in user's presence by writing is_online / last_seen_at to
 * profiles — parity with iOS PresenceManager. Online on mount + tab focus, with a
 * periodic heartbeat; offline on tab hide, unload, and unmount.
 */
export function usePresence() {
  const { user } = useAuth();

  useEffect(() => {
    if (!user?.id) return;
    const uid = user.id;
    let timer: ReturnType<typeof setInterval> | undefined;

    const goOnline = () => {
      void writePresence(uid, true);
      timer ??= setInterval(() => void writePresence(uid, true), HEARTBEAT_MS);
    };
    const goOffline = () => {
      if (timer) {
        clearInterval(timer);
        timer = undefined;
      }
      void writePresence(uid, false);
    };
    const onVisibility = () => (document.visibilityState === 'visible' ? goOnline() : goOffline());

    goOnline();
    document.addEventListener('visibilitychange', onVisibility);
    window.addEventListener('focus', goOnline);
    window.addEventListener('beforeunload', goOffline);

    return () => {
      document.removeEventListener('visibilitychange', onVisibility);
      window.removeEventListener('focus', goOnline);
      window.removeEventListener('beforeunload', goOffline);
      goOffline();
    };
  }, [user?.id]);
}
