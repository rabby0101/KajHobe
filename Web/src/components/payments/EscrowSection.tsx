import { Clock, Lock, ArrowUpRight, CheckCircle2, Undo2, XCircle, Scale, ShieldCheck } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';
import { useAuth } from '@/contexts/AuthContext';
import { useEscrow, useIsAdmin, useAdminEscrowAction } from '@/hooks/useEscrow';
import { ESCROW_STATE_META, escrowRoleCopy, formatTaka } from '@/lib/escrow';
import { toast } from '@/hooks/use-toast';

const ICONS = { Clock, Lock, ArrowUpRight, CheckCircle2, Undo2, XCircle, Scale } as const;

/** "Escrow & Payment" card for the deal-detail page (parity with iOS EscrowSectionView). */
export default function EscrowSection({ dealId }: { dealId: string }) {
  const { user } = useAuth();
  const { data: escrow, isLoading } = useEscrow(dealId);
  const { data: isAdmin } = useIsAdmin();
  const adminAction = useAdminEscrowAction();

  const runAdmin = (action: 'payout' | 'refund') => {
    if (!escrow) return;
    adminAction.mutate(
      { escrowId: escrow.id, action, note: action === 'payout' ? 'Manual bKash payout' : 'Manual refund' },
      {
        onSuccess: () => toast({ title: action === 'payout' ? 'Marked paid out' : 'Marked refunded' }),
        onError: (e) => toast({ title: 'Action failed', description: (e as Error).message, variant: 'destructive' }),
      }
    );
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <ShieldCheck className="h-5 w-5 text-indigo-500" />
          Escrow & Payment
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {isLoading ? (
          <p className="text-sm text-muted-foreground">Loading…</p>
        ) : !escrow ? (
          <p className="text-sm text-muted-foreground">No payment record for this deal.</p>
        ) : (
          (() => {
            const meta = ESCROW_STATE_META[escrow.state];
            const Icon = ICONS[meta.icon];
            const isBuyer = escrow.client_id === user?.id;
            return (
              <>
                <Badge variant="secondary" className={cn(meta.className, 'gap-1 border-0')}>
                  <Icon className="h-3.5 w-3.5" />
                  {meta.label}
                </Badge>
                <p className="text-sm text-muted-foreground">{escrowRoleCopy(escrow.state, isBuyer)}</p>
                <div className="flex items-baseline gap-2">
                  <span className="text-xl font-bold">{formatTaka(escrow.amount)}</span>
                  <span className="text-xs text-muted-foreground">
                    {escrow.state === 'paid_out' ? 'paid to provider' : 'deal amount'}
                  </span>
                </div>

                {isAdmin && (
                  <div className="space-y-2 border-t pt-3">
                    <p className="text-xs font-medium text-muted-foreground">Admin</p>
                    <div className="flex flex-wrap gap-2">
                      {escrow.state === 'released' && (
                        <Button size="sm" disabled={adminAction.isPending} onClick={() => runAdmin('payout')}>
                          <ArrowUpRight className="mr-1 h-4 w-4" />
                          Mark paid out
                        </Button>
                      )}
                      {(escrow.state === 'held' || escrow.state === 'released') && (
                        <Button
                          size="sm"
                          variant="outline"
                          disabled={adminAction.isPending}
                          onClick={() => runAdmin('refund')}
                        >
                          <Undo2 className="mr-1 h-4 w-4" />
                          Refund buyer
                        </Button>
                      )}
                    </div>
                  </div>
                )}
              </>
            );
          })()
        )}
      </CardContent>
    </Card>
  );
}
