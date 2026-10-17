import { CreditCard } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useStartCollection } from '@/hooks/useEscrow';
import { toast } from '@/hooks/use-toast';

interface AcceptAndPayButtonProps {
  dealOfferId: string;
  className?: string;
  size?: 'default' | 'sm';
}

/**
 * Accept an offer and pay into escrow. Starts an SSLCommerz hosted checkout
 * (cards + bKash/Nagad/Rocket) for the deal offer, then redirects to the
 * returned URL. On a validated payment the webhook creates the deal and holds
 * the escrow (parity with iOS "Accept & Pay").
 */
export default function AcceptAndPayButton({ dealOfferId, className, size = 'default' }: AcceptAndPayButtonProps) {
  const startCollection = useStartCollection();

  const handleClick = () => {
    startCollection.mutate(dealOfferId, {
      onSuccess: (url) => {
        // Full-page redirect to the SSLCommerz gateway page (web flow vs iOS
        // in-app session); the buyer picks card/bKash/Nagad there.
        window.location.href = url;
      },
      onError: (e) =>
        toast({ title: 'Could not start payment', description: (e as Error).message, variant: 'destructive' }),
    });
  };

  return (
    <Button onClick={handleClick} disabled={startCollection.isPending} className={className} size={size}>
      <CreditCard className="mr-1 h-4 w-4" />
      {startCollection.isPending ? 'Starting payment…' : 'Accept & Pay'}
    </Button>
  );
}
