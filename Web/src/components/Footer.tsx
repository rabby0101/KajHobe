import { Facebook, Instagram, Mail, MapPin } from "lucide-react";
import { Link } from "react-router-dom";
import { serviceCategories, getCategorySlug, categoryLabel } from "@/lib/categories";
import { useLanguage } from "@/contexts/LanguageContext";

// Top categories surfaced in the footer (real names → working /category/:slug links).
const footerCategories = serviceCategories.slice(0, 5);

const Footer = () => {
  const { t, language } = useLanguage();

  return (
    <footer className="bg-[#101d3b] text-slate-100">
      <div className="container mx-auto px-4 py-12">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
          {/* Company Info */}
          <div>
            <div className="flex items-center space-x-2 mb-4">
              <div className="w-8 h-8 bg-primary rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-sm">K</span>
              </div>
              <span className="font-bold text-xl">KajHobe</span>
            </div>
            <p className="text-sm text-gray-300 mb-4 leading-relaxed">
              {t('footer.tagline')}
            </p>
            <div className="flex space-x-4">
              <a
                href="https://www.facebook.com/profile.php?id=61590490036064"
                target="_blank"
                rel="noopener noreferrer"
                aria-label="KajHobe on Facebook"
              >
                <Facebook className="w-5 h-5 text-gray-300 hover:text-primary cursor-pointer transition-colors" />
              </a>
              <Instagram className="w-5 h-5 text-gray-300 hover:text-primary cursor-pointer transition-colors" />
            </div>
          </div>

          {/* Quick Links */}
          <div>
            <h3 className="font-semibold text-lg mb-4">{t('footer.quickLinks')}</h3>
            <ul className="space-y-2 text-sm">
              <li><Link to="/jobs" className="text-gray-300 hover:text-primary transition-colors">{t('footer.browseServices')}</Link></li>
              <li><Link to="/post-job" className="text-gray-300 hover:text-primary transition-colors">{t('footer.postJob')}</Link></li>
              <li><Link to="/auth" className="text-gray-300 hover:text-primary transition-colors">{t('footer.becomeProvider')}</Link></li>
              <li><a href="#how-it-works" className="text-gray-300 hover:text-primary transition-colors">{t('footer.howItWorks')}</a></li>
              <li><Link to="/support" className="text-gray-300 hover:text-primary transition-colors">{t('footer.safetyGuidelines')}</Link></li>
            </ul>
          </div>

          {/* Categories */}
          <div>
            <h3 className="font-semibold text-lg mb-4">{t('footer.popularCategories')}</h3>
            <ul className="space-y-2 text-sm">
              {footerCategories.map((category) => (
                <li key={category.id}>
                  <Link
                    to={`/category/${getCategorySlug(category.name)}`}
                    className="text-gray-300 hover:text-primary transition-colors"
                  >
                    {categoryLabel(category, language)}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Contact */}
          <div>
            <h3 className="font-semibold text-lg mb-4">{t('footer.contactUs')}</h3>
            <div className="space-y-3 text-sm">
              <div className="flex items-center">
                <MapPin className="w-4 h-4 text-primary mr-3" />
                <span className="text-gray-300">{t('footer.location')}</span>
              </div>
              <div className="flex items-center">
                <Mail className="w-4 h-4 text-primary mr-3" />
                <a href="mailto:support@kajhobe.bd" className="text-gray-300 hover:text-primary transition-colors">
                  support@kajhobe.bd
                </a>
              </div>
            </div>

            <div className="mt-6">
              <h4 className="font-medium mb-2">{t('footer.areasWeServe')}</h4>
              <p className="text-xs text-gray-300 leading-relaxed">
                {t('footer.areasList')}
              </p>
            </div>
          </div>
        </div>

        <div className="border-t border-white/10 mt-8 pt-8">
          <div className="flex flex-col md:flex-row justify-between items-center">
            <p className="text-sm text-gray-300">
              {t('footer.rights')}
            </p>
            <div className="flex space-x-6 mt-4 md:mt-0">
              <Link to="/privacy" className="text-sm text-gray-300 hover:text-primary transition-colors">{t('footer.privacyPolicy')}</Link>
              <Link to="/terms" className="text-sm text-gray-300 hover:text-primary transition-colors">{t('footer.termsOfService')}</Link>
              <Link to="/support" className="text-sm text-gray-300 hover:text-primary transition-colors">{t('footer.support')}</Link>
            </div>
          </div>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
