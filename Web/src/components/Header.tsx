
import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { useAuth } from '@/contexts/AuthContext';
import { useLanguage } from '@/contexts/LanguageContext';
import ThemeToggle from './ThemeToggle';
import UserMenu from './UserMenu';
import NotificationCenter from './NotificationCenter';
import { PlusIcon } from 'lucide-react';
import Logo from './Logo';

const Header = () => {
  const { user } = useAuth();
  const { t } = useLanguage();
  const navigate = useNavigate();

  return (
    <header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 md:block">
      <div className="container flex h-16 items-center">
        <div className="mr-4 flex">
          <Logo className="mr-6" />
        </div>
        
        <nav className="hidden md:flex items-center space-x-6 text-sm font-medium flex-1">
          <Link
            to="/jobs"
            className="transition-colors hover:text-foreground/80 text-foreground/60"
          >
            {t('header.browseJobs')}
          </Link>
          <Link
            to="/my-jobs"
            className="transition-colors hover:text-foreground/80 text-foreground/60"
          >
            {t('header.myJobs')}
          </Link>
          <Link
            to="/messages"
            className="transition-colors hover:text-foreground/80 text-foreground/60"
          >
            Messages
          </Link>
          <Link
            to="/dashboard"
            className="transition-colors hover:text-foreground/80 text-foreground/60"
          >
            Dashboard
          </Link>
        </nav>

        <div className="flex items-center space-x-2 ml-auto">
          {user && <NotificationCenter />}
          <ThemeToggle />
          {user ? (
            <>
              <Button 
                onClick={() => navigate('/post-job')} 
                size="sm"
                className="hidden sm:flex"
              >
                <PlusIcon className="h-4 w-4 mr-2 fill-current" />
                {t('header.postJob')}
              </Button>
              <UserMenu />
            </>
          ) : (
            <Button asChild>
              <Link to="/auth">{t('header.signIn')}</Link>
            </Button>
          )}
        </div>
      </div>
    </header>
  );
};

export default Header;
