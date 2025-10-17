import React, { useEffect, useState } from 'react';
import { useIsFetching } from '@tanstack/react-query';
import { RefreshCw } from 'lucide-react';

const AutoRefreshIndicator: React.FC = () => {
  const isFetching = useIsFetching();
  const [showIndicator, setShowIndicator] = useState(false);

  useEffect(() => {
    if (isFetching > 0) {
      setShowIndicator(true);
      const timer = setTimeout(() => {
        setShowIndicator(false);
      }, 2000);
      return () => clearTimeout(timer);
    }
  }, [isFetching]);

  if (!showIndicator) return null;

  return (
    <div className="fixed top-4 right-4 z-50 bg-blue-500 text-white px-3 py-2 rounded-full shadow-lg flex items-center space-x-2">
      <RefreshCw className="h-4 w-4 animate-spin" />
      <span className="text-sm">Refreshing...</span>
    </div>
  );
};

export default AutoRefreshIndicator;