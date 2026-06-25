import { useEffect, useState } from 'react';
import { Clock } from 'lucide-react';
import { Progress } from '@/components/ui/progress';
import { formatTimeRemaining, calculateCooldownProgress } from '@/lib/interestCooldown';

interface CooldownTimerProps {
  /** Epoch ms when the cooldown ends. */
  until: number;
  /** Fired once the countdown reaches zero. */
  onComplete?: () => void;
  label?: string;
}

/** Live countdown for an interest cooldown (parity with iOS CooldownTimerView). */
export default function CooldownTimer({ until, onComplete, label }: CooldownTimerProps) {
  const [remaining, setRemaining] = useState(() => Math.max(0, until - Date.now()));

  useEffect(() => {
    const tick = () => {
      const next = Math.max(0, until - Date.now());
      setRemaining(next);
      if (next <= 0) onComplete?.();
    };
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [until, onComplete]);

  return (
    <div className="space-y-1">
      <div className="flex items-center gap-1.5 text-sm text-muted-foreground">
        <Clock className="h-3.5 w-3.5" />
        <span>{label ?? 'Try again in'} {formatTimeRemaining(remaining)}</span>
      </div>
      <Progress value={calculateCooldownProgress(remaining) * 100} className="h-1.5" />
    </div>
  );
}
