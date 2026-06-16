import { usePresence } from '@/hooks/usePresence';

/** Headless component: drives presence writes for the signed-in user. */
export default function PresenceTracker() {
  usePresence();
  return null;
}
