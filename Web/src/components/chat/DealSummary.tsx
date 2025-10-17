
import React from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { CheckCircle, Calendar, Clock, DollarSign, User } from 'lucide-react';

interface DealSummaryProps {
  deal: {
    id: string;
    serviceDescription: string;
    agreedAmount: number;
    serviceDate: string;
    serviceTime: string;
    status: string;
    created_at: string;
  };
  isProvider?: boolean;
  onMarkCompleted?: () => void;
  onUploadProof?: () => void;
}

const DealSummary: React.FC<DealSummaryProps> = ({
  deal,
  isProvider = false,
  onMarkCompleted,
  onUploadProof
}) => {
  const getStatusBadge = () => {
    switch (deal.status) {
      case 'active':
        return <Badge className="bg-blue-100 text-blue-800">📋 In Progress</Badge>;
      case 'completed':
        return <Badge className="bg-green-100 text-green-800">✅ Completed</Badge>;
      default:
        return <Badge variant="outline">{deal.status}</Badge>;
    }
  };

  return (
    <Card className="bg-green-50 border-green-200">
      <CardHeader className="pb-3">
        <CardTitle className="flex items-center justify-between text-base">
          <div className="flex items-center gap-2">
            <CheckCircle className="h-4 w-4 text-green-600" />
            Deal Confirmed
          </div>
          {getStatusBadge()}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        <div>
          <h4 className="font-semibold text-sm text-muted-foreground">Service</h4>
          <p className="text-sm">{deal.serviceDescription}</p>
        </div>

        <div className="flex items-center justify-between">
          <div className="flex items-center gap-1">
            <DollarSign className="h-4 w-4 text-green-600" />
            <span className="font-bold text-lg text-green-600">৳{deal.agreedAmount}</span>
          </div>
        </div>

        <div className="flex items-center gap-4 text-sm text-muted-foreground">
          <div className="flex items-center gap-1">
            <Calendar className="h-3 w-3" />
            {new Date(deal.serviceDate).toLocaleDateString()}
          </div>
          <div className="flex items-center gap-1">
            <Clock className="h-3 w-3" />
            {deal.serviceTime}
          </div>
        </div>

        {isProvider && deal.status === 'active' && (
          <div className="flex gap-2 pt-2">
            <Button
              size="sm"
              variant="outline"
              onClick={onUploadProof}
              className="flex-1"
            >
              📷 Upload Proof
            </Button>
            <Button
              size="sm"
              onClick={onMarkCompleted}
              className="flex-1"
            >
              ✅ Mark Complete
            </Button>
          </div>
        )}

        <div className="text-xs text-muted-foreground">
          Deal created: {new Date(deal.created_at).toLocaleDateString()}
        </div>
      </CardContent>
    </Card>
  );
};

export default DealSummary;
