
import React, { createContext, useContext, useState, useEffect } from 'react';

type Language = 'en' | 'bn';

interface LanguageContextType {
  language: Language;
  setLanguage: (language: Language) => void;
  t: (key: string) => string;
}

const LanguageContext = createContext<LanguageContextType | undefined>(undefined);

// Translation dictionary
const translations = {
  en: {
    // Header
    'header.browseJobs': 'Browse Jobs',
    'header.myJobs': 'My Jobs',
    'header.postJob': 'Post Job',
    'header.signIn': 'Sign In',
    
    // Settings
    'settings.title': 'Settings',
    'settings.appearance': 'Appearance',
    'settings.theme': 'Theme',
    'settings.themeDesc': 'Choose your preferred theme',
    'settings.language': 'Language',
    'settings.languageDesc': 'Choose your preferred language',
    'settings.notifications': 'Notifications',
    'settings.emailNotifications': 'Email Notifications',
    'settings.emailNotificationsDesc': 'Receive notifications via email',
    'settings.jobAlerts': 'Job Alerts',
    'settings.jobAlertsDesc': 'Get notified about new jobs',
    'settings.bidUpdates': 'Bid Updates',
    'settings.bidUpdatesDesc': 'Get notified about bid responses',
    'settings.privacy': 'Privacy & Security',
    'settings.profileVisibility': 'Profile Visibility',
    'settings.profileVisibilityDesc': 'Make your profile visible to others',
    'settings.showContactInfo': 'Show Contact Info',
    'settings.showContactInfoDesc': 'Allow others to see your contact information',
    'settings.account': 'Account',
    'settings.signOut': 'Sign Out',
    'settings.signedOut': 'Signed out',
    'settings.signedOutDesc': 'You have been successfully signed out',
    'settings.error': 'Error',
    'settings.signOutError': 'Failed to sign out',
    
    // Hero Section
    'hero.title': 'Connect with Local Service Providers in',
    'hero.subtitle': 'KajHobe makes it easy to find trusted professionals for home repairs, cleaning, tutoring, and more. Post your job and get matched with skilled service providers in your area.',
    'hero.getStarted': 'Get Started',
    'hero.findServices': 'Find Services',
    'hero.findServicesDesc': 'Browse available services or post your job requirements',
    'hero.connect': 'Connect',
    'hero.connectDesc': 'Chat with service providers and negotiate terms',
    'hero.getItDone': 'Get It Done',
    'hero.getItDoneDesc': 'Complete your project with trusted local professionals',
    
    // User Menu
    'userMenu.profile': 'Profile',
    'userMenu.settings': 'Settings',
    'userMenu.logOut': 'Log out',
    
    // Theme values
    'theme.light': 'Light',
    'theme.dark': 'Dark',
    
    // Language values
    'language.english': 'English',
    'language.bengali': 'Bengali',
  },
  bn: {
    // Header
    'header.browseJobs': 'কাজ খুঁজুন',
    'header.myJobs': 'আমার কাজসমূহ',
    'header.postJob': 'কাজ পোস্ট করুন',
    'header.signIn': 'সাইন ইন',
    
    // Settings
    'settings.title': 'সেটিংস',
    'settings.appearance': 'চেহারা',
    'settings.theme': 'থিম',
    'settings.themeDesc': 'আপনার পছন্দের থিম বেছে নিন',
    'settings.language': 'ভাষা',
    'settings.languageDesc': 'আপনার পছন্দের ভাষা বেছে নিন',
    'settings.notifications': 'নোটিফিকেশন',
    'settings.emailNotifications': 'ইমেইল নোটিফিকেশন',
    'settings.emailNotificationsDesc': 'ইমেইলের মাধ্যমে নোটিফিকেশন পান',
    'settings.jobAlerts': 'কাজের সতর্কতা',
    'settings.jobAlertsDesc': 'নতুন কাজ সম্পর্কে অবহিত হন',
    'settings.bidUpdates': 'বিড আপডেট',
    'settings.bidUpdatesDesc': 'বিড প্রতিক্রিয়া সম্পর্কে অবহিত হন',
    'settings.privacy': 'গোপনীয়তা এবং নিরাপত্তা',
    'settings.profileVisibility': 'প্রোফাইল দৃশ্যমানতা',
    'settings.profileVisibilityDesc': 'অন্যদের কাছে আপনার প্রোফাইল দৃশ্যমান করুন',
    'settings.showContactInfo': 'যোগাযোগের তথ্য দেখান',
    'settings.showContactInfoDesc': 'অন্যদের আপনার যোগাযোগের তথ্য দেখার অনুমতি দিন',
    'settings.account': 'অ্যাকাউন্ট',
    'settings.signOut': 'সাইন আউট',
    'settings.signedOut': 'সাইন আউট হয়েছে',
    'settings.signedOutDesc': 'আপনি সফলভাবে সাইন আউট হয়েছেন',
    'settings.error': 'ত্রুটি',
    'settings.signOutError': 'সাইন আউট করতে ব্যর্থ',
    
    // Hero Section
    'hero.title': 'খুলনায় স্থানীয় সেবা প্রদানকারীদের সাথে যুক্ত হন',
    'hero.subtitle': 'KajHobe ঘর মেরামত, পরিষ্কার-পরিচ্ছন্নতা, টিউটরিং এবং আরও অনেক কিছুর জন্য বিশ্বস্ত পেশাদারদের খুঁজে পেতে সহজ করে তোলে। আপনার কাজ পোস্ট করুন এবং আপনার এলাকার দক্ষ সেবা প্রদানকারীদের সাথে মিলিত হন।',
    'hero.getStarted': 'শুরু করুন',
    'hero.findServices': 'সেবা খুঁজুন',
    'hero.findServicesDesc': 'উপলভ্য সেবা ব্রাউজ করুন বা আপনার কাজের প্রয়োজন পোস্ট করুন',
    'hero.connect': 'সংযোগ',
    'hero.connectDesc': 'সেবা প্রদানকারীদের সাথে চ্যাট করুন এবং শর্তাবলী নিয়ে আলোচনা করুন',
    'hero.getItDone': 'সম্পন্ন করুন',
    'hero.getItDoneDesc': 'বিশ্বস্ত স্থানীয় পেশাদারদের সাথে আপনার প্রকল্প সম্পূর্ণ করুন',
    
    // User Menu
    'userMenu.profile': 'প্রোফাইল',
    'userMenu.settings': 'সেটিংস',
    'userMenu.logOut': 'লগ আউট',
    
    // Theme values
    'theme.light': 'হালকা',
    'theme.dark': 'গাঢ়',
    
    // Language values
    'language.english': 'ইংরেজি',
    'language.bengali': 'বাংলা',
  },
};

export const LanguageProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [language, setLanguageState] = useState<Language>('en');

  useEffect(() => {
    const savedLanguage = localStorage.getItem('language') as Language;
    if (savedLanguage && (savedLanguage === 'en' || savedLanguage === 'bn')) {
      setLanguageState(savedLanguage);
    }
  }, []);

  const setLanguage = (newLanguage: Language) => {
    setLanguageState(newLanguage);
    localStorage.setItem('language', newLanguage);
  };

  const t = (key: string): string => {
    return translations[language][key as keyof typeof translations['en']] || key;
  };

  return (
    <LanguageContext.Provider value={{ language, setLanguage, t }}>
      {children}
    </LanguageContext.Provider>
  );
};

export const useLanguage = () => {
  const context = useContext(LanguageContext);
  if (context === undefined) {
    throw new Error('useLanguage must be used within a LanguageProvider');
  }
  return context;
};
