
import React from 'react';
import { isNative } from '@/utils/capacitor';

interface MobileLayoutProps {
  children: React.ReactNode;
  className?: string;
}

const MobileLayout: React.FC<MobileLayoutProps> = ({ children, className = '' }) => {
  const native = isNative();
  
  return (
    <div className={`
      ${native ? 'pt-safe-area-top pb-safe-area-bottom' : ''}
      ${className}
    `}>
      {children}
    </div>
  );
};

export default MobileLayout;
