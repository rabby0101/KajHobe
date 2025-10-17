
import React from 'react';
import { Button } from '@/components/ui/button';
import { ArrowRightIcon, SearchIcon, UsersIcon } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { useLanguage } from '@/contexts/LanguageContext';

const HeroSection = () => {
  const { user } = useAuth();
  const { t } = useLanguage();

  return (
    <section className="relative overflow-hidden bg-gradient-to-br from-blue-50 via-white to-purple-50 dark:from-gray-900 dark:via-gray-800 dark:to-gray-900">
      <div className="container mx-auto px-4 py-20 sm:py-32">
        <div className="mx-auto max-w-4xl text-center">
          <h1 className="text-4xl font-bold tracking-tight text-gray-900 dark:text-white sm:text-6xl">
            {t('hero.title')}{' '}
            <span className="gradient-text">Khulna</span>
          </h1>
          <p className="mt-6 text-lg leading-8 text-gray-600 dark:text-gray-300 max-w-2xl mx-auto">
            {t('hero.subtitle')}
          </p>
          
          <div className="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
            {user ? (
              <>
                <Button asChild size="lg" className="w-full sm:w-auto">
                  <Link to="/jobs" className="flex items-center">
                    <SearchIcon className="h-5 w-5 mr-2 fill-current" />
                    {t('header.browseJobs')}
                  </Link>
                </Button>
                <Button asChild variant="outline" size="lg" className="w-full sm:w-auto">
                  <Link to="/post-job" className="flex items-center">
                    <ArrowRightIcon className="h-5 w-5 mr-2 fill-current" />
                    {t('header.postJob')}
                  </Link>
                </Button>
              </>
            ) : (
              <>
                <Button asChild size="lg" className="w-full sm:w-auto">
                  <Link to="/auth" className="flex items-center">
                    {t('hero.getStarted')}
                    <ArrowRightIcon className="h-5 w-5 ml-2 fill-current" />
                  </Link>
                </Button>
                <Button asChild variant="outline" size="lg" className="w-full sm:w-auto">
                  <Link to="/jobs" className="flex items-center">
                    <SearchIcon className="h-5 w-5 mr-2 fill-current" />
                    {t('header.browseJobs')}
                  </Link>
                </Button>
              </>
            )}
          </div>

          <div className="mt-16 grid grid-cols-1 sm:grid-cols-3 gap-8 text-center">
            <div className="flex flex-col items-center">
              <div className="rounded-full bg-blue-100 dark:bg-blue-900 p-3 mb-4">
                <SearchIcon className="h-8 w-8 text-blue-600 dark:text-blue-400 fill-current" />
              </div>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">{t('hero.findServices')}</h3>
              <p className="text-gray-600 dark:text-gray-300">{t('hero.findServicesDesc')}</p>
            </div>
            
            <div className="flex flex-col items-center">
              <div className="rounded-full bg-green-100 dark:bg-green-900 p-3 mb-4">
                <UsersIcon className="h-8 w-8 text-green-600 dark:text-green-400 fill-current" />
              </div>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">{t('hero.connect')}</h3>
              <p className="text-gray-600 dark:text-gray-300">{t('hero.connectDesc')}</p>
            </div>
            
            <div className="flex flex-col items-center">
              <div className="rounded-full bg-purple-100 dark:bg-purple-900 p-3 mb-4">
                <ArrowRightIcon className="h-8 w-8 text-purple-600 dark:text-purple-400 fill-current" />
              </div>
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">{t('hero.getItDone')}</h3>
              <p className="text-gray-600 dark:text-gray-300">{t('hero.getItDoneDesc')}</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default HeroSection;
