import React from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useLocation } from 'react-router-dom';
import BottomNavigation from './BottomNavigation';

const ConditionalBottomNavigation: React.FC = () => {
  const { user, loading } = useAuth();
  const location = useLocation();

  // Don't show bottom navigation if:
  // 1. User is not authenticated
  // 2. Still loading authentication state
  // 3. User is on the auth page
  if (!user || loading || location.pathname === '/auth') {
    return null;
  }

  return <BottomNavigation />;
};

export default ConditionalBottomNavigation;