
import React, { createContext, useContext, useState, useEffect } from 'react';

type Language = 'en' | 'bn' | 'de';

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
    'language.german': 'German',

    // Home
    'home.searchPlaceholder': 'Search jobs...',
    'home.serviceCategories': 'Service Categories',
    'home.favouriteCategories': 'Your Favourite Categories',
    'home.favouriteCategoriesDesc': 'Quick access to your preferred services',
    'home.jobsNearYou': 'Jobs Near You',
    'home.jobsNearYouDesc': 'Opportunities in your area',
    'home.featuredJobs': 'Featured Jobs',
    'home.featuredJobsDesc': 'Urgent and high-value opportunities',
    'home.recentJobs': 'Recently Posted Jobs',
    'home.recentJobsDesc': 'The latest jobs in Khulna',
    'home.viewAll': 'View All',
    'home.searchResults': 'Search Results',
    'home.allCategory': 'All',
    'common.jobsCount': 'jobs',
    'common.loading': 'Loading...',

    // Post Job
    'post.title': 'Post a New Job',
    'post.jobTitle': 'Job Title',
    'post.jobTitlePlaceholder': 'e.g., Need Electrician for Ceiling Fan Installation',
    'post.category': 'Category',
    'post.selectCategory': 'Select a category',
    'post.description': 'Description',
    'post.descriptionPlaceholder': 'Describe what you need done, when you need it, and any specific requirements...',
    'post.budget': 'Budget (৳)',
    'post.location': 'Location',
    'post.locationPlaceholder': 'e.g., Sonadanga, Khulna',
    'post.urgent': 'This is urgent',
    'post.submit': 'Post Job',
    'post.submitting': 'Posting...',

    // How It Works
    'howItWorks.title': 'How It Works',
    'howItWorks.subtitle': 'Getting your service needs fulfilled is simple and straightforward',
    'howItWorks.step1.title': 'Post Your Need',
    'howItWorks.step1.desc': 'Describe what service you need with details, budget, and timeline',
    'howItWorks.step2.title': 'Get Proposals',
    'howItWorks.step2.desc': 'Qualified service providers will contact you with quotes and offers',
    'howItWorks.step3.title': 'Choose & Connect',
    'howItWorks.step3.desc': 'Review profiles, ratings, and select the best provider for your job',
    'howItWorks.step4.title': 'Get It Done',
    'howItWorks.step4.desc': 'Complete the service and rate your experience to help others',

    // Featured Providers
    'featuredProviders.title': 'Featured Service Providers',
    'featuredProviders.subtitle': 'Top-rated, verified professionals from the KajHobe community',
    'featuredProviders.comingSoon': 'Coming soon',
    'featuredProviders.comingSoonDesc': "We're onboarding and verifying providers across Khulna. Featured profiles will appear here once they're ready.",

    // Footer
    'footer.tagline': 'Connecting Khulna residents with trusted local service providers. Your one-stop solution for getting work done.',
    'footer.quickLinks': 'Quick Links',
    'footer.browseServices': 'Browse Services',
    'footer.postJob': 'Post a Job',
    'footer.becomeProvider': 'Become a Provider',
    'footer.howItWorks': 'How It Works',
    'footer.safetyGuidelines': 'Safety Guidelines',
    'footer.popularCategories': 'Popular Categories',
    'footer.contactUs': 'Contact Us',
    'footer.location': 'Khulna, Bangladesh',
    'footer.areasWeServe': 'Areas We Serve',
    'footer.areasList': 'Sonadanga • Daulatpur • Khalishpur • Khan Jahan Ali • Boyra • Rupsha • All areas in Khulna',
    'footer.rights': '© 2026 KajHobe. All rights reserved.',
    'footer.privacyPolicy': 'Privacy Policy',
    'footer.termsOfService': 'Terms of Service',
    'footer.support': 'Support',
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
    'language.german': 'জার্মান',

    // Home
    'home.searchPlaceholder': 'কাজ খুঁজুন...',
    'home.serviceCategories': 'সেবা ক্যাটাগরি',
    'home.favouriteCategories': 'আপনার পছন্দের ক্যাটাগরি',
    'home.favouriteCategoriesDesc': 'আপনার পছন্দের সেবায় দ্রুত প্রবেশ',
    'home.jobsNearYou': 'আপনার কাছাকাছি কাজ',
    'home.jobsNearYouDesc': 'আপনার এলাকার সুযোগ',
    'home.featuredJobs': 'ফিচার্ড কাজ',
    'home.featuredJobsDesc': 'জরুরি এবং বেশি বাজেটের সুযোগ',
    'home.recentJobs': 'সম্প্রতি পোস্ট করা কাজ',
    'home.recentJobsDesc': 'খুলনার সর্বশেষ কাজ',
    'home.viewAll': 'সব দেখুন',
    'home.searchResults': 'অনুসন্ধানের ফলাফল',
    'home.allCategory': 'সব কাজ',
    'common.jobsCount': 'টি কাজ',
    'common.loading': 'লোড হচ্ছে...',

    // Post Job
    'post.title': 'নতুন কাজ পোস্ট করুন',
    'post.jobTitle': 'কাজের শিরোনাম',
    'post.jobTitlePlaceholder': 'যেমন, সিলিং ফ্যান লাগানোর জন্য ইলেকট্রিশিয়ান দরকার',
    'post.category': 'ক্যাটাগরি',
    'post.selectCategory': 'একটি ক্যাটাগরি নির্বাচন করুন',
    'post.description': 'বিবরণ',
    'post.descriptionPlaceholder': 'আপনার কী কাজ করাতে চান, কখন দরকার এবং বিশেষ কোনো প্রয়োজন থাকলে লিখুন...',
    'post.budget': 'বাজেট (৳)',
    'post.location': 'অবস্থান',
    'post.locationPlaceholder': 'যেমন, সোনাডাঙ্গা, খুলনা',
    'post.urgent': 'এটি জরুরি',
    'post.submit': 'কাজ পোস্ট করুন',
    'post.submitting': 'পোস্ট করা হচ্ছে...',

    // How It Works
    'howItWorks.title': 'কীভাবে কাজ করে',
    'howItWorks.subtitle': 'আপনার সেবার প্রয়োজন পূরণ করা সহজ এবং সরল',
    'howItWorks.step1.title': 'আপনার প্রয়োজন পোস্ট করুন',
    'howItWorks.step1.desc': 'বিস্তারিত, বাজেট এবং সময়সীমাসহ আপনার প্রয়োজনীয় সেবা বর্ণনা করুন',
    'howItWorks.step2.title': 'প্রস্তাব পান',
    'howItWorks.step2.desc': 'যোগ্য সেবা প্রদানকারীরা কোটেশন ও অফার নিয়ে আপনার সাথে যোগাযোগ করবে',
    'howItWorks.step3.title': 'বেছে নিন ও যোগাযোগ করুন',
    'howItWorks.step3.desc': 'প্রোফাইল, রেটিং পর্যালোচনা করুন এবং আপনার কাজের জন্য সেরা প্রদানকারী নির্বাচন করুন',
    'howItWorks.step4.title': 'কাজ সম্পন্ন করুন',
    'howItWorks.step4.desc': 'সেবা সম্পন্ন করুন এবং অন্যদের সাহায্য করতে আপনার অভিজ্ঞতা রেট করুন',

    // Featured Providers
    'featuredProviders.title': 'ফিচার্ড সেবা প্রদানকারী',
    'featuredProviders.subtitle': 'KajHobe কমিউনিটির সেরা রেটিংপ্রাপ্ত, যাচাইকৃত পেশাদাররা',
    'featuredProviders.comingSoon': 'শীঘ্রই আসছে',
    'featuredProviders.comingSoonDesc': 'আমরা খুলনা জুড়ে প্রদানকারীদের অন্তর্ভুক্ত ও যাচাই করছি। প্রস্তুত হলে ফিচার্ড প্রোফাইল এখানে দেখা যাবে।',

    // Footer
    'footer.tagline': 'খুলনার বাসিন্দাদের বিশ্বস্ত স্থানীয় সেবা প্রদানকারীদের সাথে সংযুক্ত করা। কাজ সম্পন্ন করার জন্য আপনার এক-স্টপ সমাধান।',
    'footer.quickLinks': 'দ্রুত লিংক',
    'footer.browseServices': 'সেবা ব্রাউজ করুন',
    'footer.postJob': 'কাজ পোস্ট করুন',
    'footer.becomeProvider': 'প্রদানকারী হন',
    'footer.howItWorks': 'কীভাবে কাজ করে',
    'footer.safetyGuidelines': 'নিরাপত্তা নির্দেশিকা',
    'footer.popularCategories': 'জনপ্রিয় ক্যাটাগরি',
    'footer.contactUs': 'যোগাযোগ করুন',
    'footer.location': 'খুলনা, বাংলাদেশ',
    'footer.areasWeServe': 'আমরা যেসব এলাকায় সেবা দিই',
    'footer.areasList': 'সোনাডাঙ্গা • দৌলতপুর • খালিশপুর • খান জাহান আলী • বয়রা • রূপসা • খুলনার সকল এলাকা',
    'footer.rights': '© ২০২৬ KajHobe। সর্বস্বত্ব সংরক্ষিত।',
    'footer.privacyPolicy': 'গোপনীয়তা নীতি',
    'footer.termsOfService': 'সেবার শর্তাবলী',
    'footer.support': 'সহায়তা',
  },
  de: {
    // Header
    'header.browseJobs': 'Jobs durchsuchen',
    'header.myJobs': 'Meine Jobs',
    'header.postJob': 'Job einstellen',
    'header.signIn': 'Anmelden',

    // Settings
    'settings.title': 'Einstellungen',
    'settings.appearance': 'Darstellung',
    'settings.theme': 'Design',
    'settings.themeDesc': 'Wähle dein bevorzugtes Design',
    'settings.language': 'Sprache',
    'settings.languageDesc': 'Wähle deine bevorzugte Sprache',
    'settings.notifications': 'Benachrichtigungen',
    'settings.emailNotifications': 'E-Mail-Benachrichtigungen',
    'settings.emailNotificationsDesc': 'Benachrichtigungen per E-Mail erhalten',
    'settings.jobAlerts': 'Job-Benachrichtigungen',
    'settings.jobAlertsDesc': 'Über neue Jobs benachrichtigt werden',
    'settings.bidUpdates': 'Angebots-Updates',
    'settings.bidUpdatesDesc': 'Über Angebotsantworten benachrichtigt werden',
    'settings.privacy': 'Datenschutz & Sicherheit',
    'settings.profileVisibility': 'Profil-Sichtbarkeit',
    'settings.profileVisibilityDesc': 'Mache dein Profil für andere sichtbar',
    'settings.showContactInfo': 'Kontaktdaten anzeigen',
    'settings.showContactInfoDesc': 'Anderen erlauben, deine Kontaktdaten zu sehen',
    'settings.account': 'Konto',
    'settings.signOut': 'Abmelden',
    'settings.signedOut': 'Abgemeldet',
    'settings.signedOutDesc': 'Du wurdest erfolgreich abgemeldet',
    'settings.error': 'Fehler',
    'settings.signOutError': 'Abmeldung fehlgeschlagen',

    // Hero Section
    'hero.title': 'Vernetze dich mit lokalen Dienstleistern in',
    'hero.subtitle': 'KajHobe macht es einfach, vertrauenswürdige Fachkräfte für Reparaturen, Reinigung, Nachhilfe und mehr zu finden. Stelle deinen Job ein und werde mit qualifizierten Dienstleistern in deiner Nähe zusammengebracht.',
    'hero.getStarted': 'Loslegen',
    'hero.findServices': 'Dienste finden',
    'hero.findServicesDesc': 'Verfügbare Dienste durchsuchen oder deinen Job einstellen',
    'hero.connect': 'Verbinden',
    'hero.connectDesc': 'Chatte mit Dienstleistern und verhandle Konditionen',
    'hero.getItDone': 'Erledigen',
    'hero.getItDoneDesc': 'Schließe dein Projekt mit vertrauenswürdigen lokalen Fachkräften ab',

    // User Menu
    'userMenu.profile': 'Profil',
    'userMenu.settings': 'Einstellungen',
    'userMenu.logOut': 'Abmelden',

    // Theme values
    'theme.light': 'Hell',
    'theme.dark': 'Dunkel',

    // Language values
    'language.english': 'Englisch',
    'language.bengali': 'Bengalisch',
    'language.german': 'Deutsch',

    // Home
    'home.searchPlaceholder': 'Jobs suchen...',
    'home.serviceCategories': 'Servicekategorien',
    'home.favouriteCategories': 'Deine bevorzugten Kategorien',
    'home.favouriteCategoriesDesc': 'Schneller Zugriff auf deine bevorzugten Dienste',
    'home.jobsNearYou': 'Jobs in deiner Nähe',
    'home.jobsNearYouDesc': 'Möglichkeiten in deiner Gegend',
    'home.featuredJobs': 'Hervorgehobene Jobs',
    'home.featuredJobsDesc': 'Dringende und hochwertige Möglichkeiten',
    'home.recentJobs': 'Kürzlich veröffentlichte Jobs',
    'home.recentJobsDesc': 'Die neuesten Jobs in Khulna',
    'home.viewAll': 'Alle ansehen',
    'home.searchResults': 'Suchergebnisse',
    'home.allCategory': 'Alle',
    'common.jobsCount': 'Jobs',
    'common.loading': 'Wird geladen...',

    // Post Job
    'post.title': 'Neuen Job einstellen',
    'post.jobTitle': 'Jobtitel',
    'post.jobTitlePlaceholder': 'z.B. Elektriker für Deckenventilator-Montage gesucht',
    'post.category': 'Kategorie',
    'post.selectCategory': 'Kategorie auswählen',
    'post.description': 'Beschreibung',
    'post.descriptionPlaceholder': 'Beschreibe, was zu tun ist, wann du es brauchst und besondere Anforderungen...',
    'post.budget': 'Budget (৳)',
    'post.location': 'Standort',
    'post.locationPlaceholder': 'z.B. Sonadanga, Khulna',
    'post.urgent': 'Das ist dringend',
    'post.submit': 'Job einstellen',
    'post.submitting': 'Wird eingestellt...',

    // How It Works
    'howItWorks.title': 'So funktioniert es',
    'howItWorks.subtitle': 'Deine Servicebedürfnisse einfach und unkompliziert erfüllt bekommen',
    'howItWorks.step1.title': 'Stelle deinen Bedarf ein',
    'howItWorks.step1.desc': 'Beschreibe, welchen Service du brauchst, mit Details, Budget und Zeitrahmen',
    'howItWorks.step2.title': 'Erhalte Angebote',
    'howItWorks.step2.desc': 'Qualifizierte Dienstleister kontaktieren dich mit Angeboten',
    'howItWorks.step3.title': 'Auswählen & Verbinden',
    'howItWorks.step3.desc': 'Prüfe Profile, Bewertungen und wähle den besten Anbieter für deinen Job',
    'howItWorks.step4.title': 'Erledigen lassen',
    'howItWorks.step4.desc': 'Schließe den Service ab und bewerte deine Erfahrung, um anderen zu helfen',

    // Featured Providers
    'featuredProviders.title': 'Empfohlene Dienstleister',
    'featuredProviders.subtitle': 'Top bewertete, verifizierte Fachkräfte aus der KajHobe-Community',
    'featuredProviders.comingSoon': 'Demnächst verfügbar',
    'featuredProviders.comingSoonDesc': 'Wir nehmen Dienstleister in ganz Khulna auf und verifizieren sie. Empfohlene Profile erscheinen hier, sobald sie bereit sind.',

    // Footer
    'footer.tagline': 'Wir verbinden Bewohner von Khulna mit vertrauenswürdigen lokalen Dienstleistern. Deine Komplettlösung, um Dinge erledigt zu bekommen.',
    'footer.quickLinks': 'Schnellzugriff',
    'footer.browseServices': 'Dienste durchsuchen',
    'footer.postJob': 'Job einstellen',
    'footer.becomeProvider': 'Dienstleister werden',
    'footer.howItWorks': 'So funktioniert es',
    'footer.safetyGuidelines': 'Sicherheitsrichtlinien',
    'footer.popularCategories': 'Beliebte Kategorien',
    'footer.contactUs': 'Kontaktiere uns',
    'footer.location': 'Khulna, Bangladesch',
    'footer.areasWeServe': 'Von uns bediente Gebiete',
    'footer.areasList': 'Sonadanga • Daulatpur • Khalishpur • Khan Jahan Ali • Boyra • Rupsha • Alle Gebiete in Khulna',
    'footer.rights': '© 2026 KajHobe. Alle Rechte vorbehalten.',
    'footer.privacyPolicy': 'Datenschutzrichtlinie',
    'footer.termsOfService': 'Nutzungsbedingungen',
    'footer.support': 'Support',
  },
};

export const LanguageProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  // Bangla is the default language for new users (KajHobe targets Khulna, BD).
  const [language, setLanguageState] = useState<Language>('bn');

  useEffect(() => {
    const savedLanguage = localStorage.getItem('language') as Language;
    if (savedLanguage && (savedLanguage === 'en' || savedLanguage === 'bn' || savedLanguage === 'de')) {
      setLanguageState(savedLanguage);
    }
  }, []);

  const setLanguage = (newLanguage: Language) => {
    setLanguageState(newLanguage);
    localStorage.setItem('language', newLanguage);
  };

  const t = (key: string): string => {
    const k = key as keyof typeof translations['en'];
    // Fall back to English for any key missing in the active language, then the key itself.
    return translations[language][k] ?? translations.en[k] ?? key;
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
