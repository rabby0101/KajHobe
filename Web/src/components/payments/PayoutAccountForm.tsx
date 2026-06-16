import { useEffect, useState } from 'react';
import { Wallet } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useMyPayoutNumber, useUpsertPayoutNumber } from '@/hooks/useEscrow';
import { isValidBkashNumber } from '@/lib/escrow';
import { toast } from '@/hooks/use-toast';

/** Manage the provider's private bKash payout number (parity with iOS payout-account upsert). */
export default function PayoutAccountForm() {
  const { data: saved, isLoading } = useMyPayoutNumber();
  const upsert = useUpsertPayoutNumber();
  const [value, setValue] = useState('');

  useEffect(() => {
    if (saved) setValue(saved);
  }, [saved]);

  const valid = isValidBkashNumber(value);

  const handleSave = () => {
    if (!valid) return;
    upsert.mutate(value, {
      onSuccess: () => toast({ title: 'Payout number saved' }),
      onError: (e) => toast({ title: 'Could not save', description: (e as Error).message, variant: 'destructive' }),
    });
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Wallet className="h-5 w-5 text-pink-500" />
          bKash payout number
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        <p className="text-sm text-muted-foreground">
          Where you'll receive payouts for completed deals. Visible only to you.
        </p>
        <div className="space-y-1.5">
          <Label htmlFor="bkash">bKash number</Label>
          <Input
            id="bkash"
            inputMode="numeric"
            placeholder="01XXXXXXXXX"
            value={value}
            disabled={isLoading}
            onChange={(e) => setValue(e.target.value)}
          />
          {value.length > 0 && !valid && (
            <p className="text-xs text-destructive">Enter a valid number in the format 01XXXXXXXXX.</p>
          )}
        </div>
        <Button onClick={handleSave} disabled={!valid || upsert.isPending}>
          {upsert.isPending ? 'Saving…' : 'Save'}
        </Button>
      </CardContent>
    </Card>
  );
}
