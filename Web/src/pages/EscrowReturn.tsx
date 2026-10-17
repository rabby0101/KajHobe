import { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { useQueryClient } from '@tanstack/react-query';
import { CheckCircle2, Clock, XCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { supabase } from '@/integrations/supabase/client';

/**
 * Landing page for the SSLCommerz browser redirect after checkout
 * (`sslcommerz-webhook` 302s web buyers here with ?deal_offer_id&status).
 * Mobile buyers return via the kajhobe:// deep link instead.
 */
export default function EscrowReturn() {
  const [params] = useSearchParams();
  const queryClient = useQueryClient();
  const dealOfferId = params.get('deal_offer_id');
  const status = params.get('status') ?? 'error';
  const [dealId, setDealId] = useState<string | null>(null);

  const isSuccess = status === 'success';
  const isCancel = status === 'cancel';

  useEffect(() => {
    // The payment may have changed offer/deal/escrow state — refetch everything.
    queryClient.invalidateQueries({ queryKey: ['escrow'] });
    queryClient.invalidateQueries({ queryKey: ['deal-offers'] });
    queryClient.invalidateQueries({ queryKey: ['messages'] });

    if (isSuccess && dealOfferId) {
      supabase
        .from('deals')
        .select('id')
        .eq('deal_offer_id', dealOfferId)
        .limit(1)
        .maybeSingle()
        .then(({ data }) => setDealId(data?.id ?? null));
    }
  }, [queryClient, isSuccess, dealOfferId]);

  const copy = isSuccess
    ? {
        icon: <CheckCircle2 className="h-12 w-12 text-green-600" />,
        title: 'Payment successful',
        body: 'Your payment is held safely in escrow. The provider can now start the work.',
      }
    : isCancel
      ? {
          icon: <Clock className="h-12 w-12 text-amber-500" />,
          title: 'Payment cancelled',
          body: 'No money was taken. You can accept and pay for the offer again anytime.',
        }
      : {
          icon: <XCircle className="h-12 w-12 text-destructive" />,
          title: 'Payment not completed',
          body: 'The payment could not be verified. If money left your account, contact support and it will be resolved.',
        };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background px-4">
      <div className="text-center max-w-md">
        <div className="flex justify-center mb-4">{copy.icon}</div>
        <h1 className="text-2xl font-bold mb-2 text-foreground">{copy.title}</h1>
        <p className="text-muted-foreground mb-6">{copy.body}</p>
        <div className="flex justify-center gap-3">
          {isSuccess && dealId && (
            <Button asChild>
              <Link to={`/deal/${dealId}`}>View deal</Link>
            </Button>
          )}
          <Button asChild variant={isSuccess && dealId ? 'outline' : 'default'}>
            <Link to="/messages">Back to messages</Link>
          </Button>
        </div>
      </div>
    </div>
  );
}
