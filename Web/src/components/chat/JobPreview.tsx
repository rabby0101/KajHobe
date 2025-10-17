
import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { MapPin, DollarSign, Clock } from 'lucide-react';

interface JobPreviewProps {
  job: {
    id: string;
    title: string;
    description: string;
    budget: number;
    location: string;
    category: string;
    urgent?: boolean;
    created_at: string;
  };
}

const JobPreview: React.FC<JobPreviewProps> = ({ job }) => {
  return (
    <Card className="bg-blue-50 border-blue-200">
      <CardContent className="p-4">
        <div className="space-y-2">
          <div className="flex items-start justify-between">
            <h3 className="font-semibold text-sm">{job.title}</h3>
            {job.urgent && (
              <Badge variant="destructive" className="text-xs">
                Urgent
              </Badge>
            )}
          </div>
          
          <p className="text-sm text-muted-foreground line-clamp-2">
            {job.description}
          </p>
          
          <div className="flex items-center justify-between text-sm">
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-1 text-primary">
                <DollarSign className="h-3 w-3" />
                <span className="font-medium">৳{job.budget}</span>
              </div>
              
              <div className="flex items-center gap-1 text-muted-foreground">
                <MapPin className="h-3 w-3" />
                <span>{job.location}</span>
              </div>
            </div>
            
            <Badge variant="outline" className="text-xs">
              {job.category}
            </Badge>
          </div>
          
          <div className="flex items-center gap-1 text-xs text-muted-foreground">
            <Clock className="h-3 w-3" />
            <span>Posted {new Date(job.created_at).toLocaleDateString()}</span>
          </div>
        </div>
      </CardContent>
    </Card>
  );
};

export default JobPreview;
