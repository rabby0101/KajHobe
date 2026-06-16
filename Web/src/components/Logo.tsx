import React from 'react';
import { Link } from 'react-router-dom';

interface LogoProps {
  className?: string;
  /** Kept for API compatibility; the wordmark already includes the name. */
  showText?: boolean;
  size?: 'sm' | 'md' | 'lg';
}

// The KajHobe wordmark (shared with iOS). Two variants so it stays legible on
// light and dark backgrounds.
const heightClasses = {
  sm: 'h-6',
  md: 'h-8',
  lg: 'h-10',
};

const Logo: React.FC<LogoProps> = ({ className = '', size = 'md' }) => {
  const h = heightClasses[size];
  return (
    <Link to="/" className={`flex items-center ${className}`} aria-label="KajHobe home">
      <img src="/kajhobe-logo.png" alt="KajHobe" className={`${h} w-auto block dark:hidden`} />
      <img src="/kajhobe-logo-dark.png" alt="KajHobe" className={`${h} w-auto hidden dark:block`} />
    </Link>
  );
};

export default Logo;
