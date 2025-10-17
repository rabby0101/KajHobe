import React from 'react';
import { Link } from 'react-router-dom';

interface LogoProps {
  className?: string;
  showText?: boolean;
  size?: 'sm' | 'md' | 'lg';
}

const Logo: React.FC<LogoProps> = ({ 
  className = '', 
  showText = true, 
  size = 'md' 
}) => {
  const sizeClasses = {
    sm: 'h-8 w-8',
    md: 'h-10 w-10',
    lg: 'h-12 w-12'
  };

  const textSizeClasses = {
    sm: 'text-lg',
    md: 'text-xl',
    lg: 'text-2xl'
  };

  return (
    <Link to="/" className={`flex items-center space-x-2 ${className}`}>
      <div className={`${sizeClasses[size]} relative`}>
        {/* Modern service hub logo - circular design with connecting elements */}
        <svg
          viewBox="0 0 40 40"
          className="w-full h-full"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          {/* Outer circle representing the hub */}
          <circle
            cx="20"
            cy="20"
            r="18"
            stroke="currentColor"
            strokeWidth="2"
            className="text-primary"
          />
          
          {/* Inner connecting nodes representing services */}
          <circle cx="20" cy="20" r="3" fill="currentColor" className="text-primary" />
          <circle cx="20" cy="8" r="2" fill="currentColor" className="text-primary" />
          <circle cx="32" cy="20" r="2" fill="currentColor" className="text-primary" />
          <circle cx="20" cy="32" r="2" fill="currentColor" className="text-primary" />
          <circle cx="8" cy="20" r="2" fill="currentColor" className="text-primary" />
          <circle cx="28" cy="12" r="1.5" fill="currentColor" className="text-primary" />
          <circle cx="28" cy="28" r="1.5" fill="currentColor" className="text-primary" />
          <circle cx="12" cy="28" r="1.5" fill="currentColor" className="text-primary" />
          <circle cx="12" cy="12" r="1.5" fill="currentColor" className="text-primary" />
          
          {/* Connecting lines representing the network */}
          <line x1="20" y1="20" x2="20" y2="8" stroke="currentColor" strokeWidth="1.5" className="text-primary" />
          <line x1="20" y1="20" x2="32" y2="20" stroke="currentColor" strokeWidth="1.5" className="text-primary" />
          <line x1="20" y1="20" x2="20" y2="32" stroke="currentColor" strokeWidth="1.5" className="text-primary" />
          <line x1="20" y1="20" x2="8" y2="20" stroke="currentColor" strokeWidth="1.5" className="text-primary" />
          <line x1="20" y1="20" x2="28" y2="12" stroke="currentColor" strokeWidth="1" className="text-primary" />
          <line x1="20" y1="20" x2="28" y2="28" stroke="currentColor" strokeWidth="1" className="text-primary" />
          <line x1="20" y1="20" x2="12" y2="28" stroke="currentColor" strokeWidth="1" className="text-primary" />
          <line x1="20" y1="20" x2="12" y2="12" stroke="currentColor" strokeWidth="1" className="text-primary" />
        </svg>
      </div>
      {showText && (
        <div className="flex flex-col">
          <span className={`font-bold ${textSizeClasses[size]} leading-tight`}>
            KajHobe
          </span>
          <span className="text-xs text-muted-foreground leading-tight">
            Services Hub
          </span>
        </div>
      )}
    </Link>
  );
};

export default Logo;