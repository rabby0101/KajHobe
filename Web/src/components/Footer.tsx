import { Facebook, Instagram, Mail, MapPin } from "lucide-react";
import { Link } from "react-router-dom";
import { serviceCategories, getCategorySlug } from "@/lib/categories";

// Top categories surfaced in the footer (real names → working /category/:slug links).
const footerCategories = serviceCategories.slice(0, 5);

const Footer = () => {
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
              Connecting Khulna residents with trusted local service providers.
              Your one-stop solution for getting work done.
            </p>
            <div className="flex space-x-4">
              <Facebook className="w-5 h-5 text-gray-300 hover:text-primary cursor-pointer transition-colors" />
              <Instagram className="w-5 h-5 text-gray-300 hover:text-primary cursor-pointer transition-colors" />
            </div>
          </div>

          {/* Quick Links */}
          <div>
            <h3 className="font-semibold text-lg mb-4">Quick Links</h3>
            <ul className="space-y-2 text-sm">
              <li><Link to="/jobs" className="text-gray-300 hover:text-primary transition-colors">Browse Services</Link></li>
              <li><Link to="/post-job" className="text-gray-300 hover:text-primary transition-colors">Post a Job</Link></li>
              <li><Link to="/auth" className="text-gray-300 hover:text-primary transition-colors">Become a Provider</Link></li>
              <li><a href="#how-it-works" className="text-gray-300 hover:text-primary transition-colors">How It Works</a></li>
              <li><Link to="/support" className="text-gray-300 hover:text-primary transition-colors">Safety Guidelines</Link></li>
            </ul>
          </div>

          {/* Categories */}
          <div>
            <h3 className="font-semibold text-lg mb-4">Popular Categories</h3>
            <ul className="space-y-2 text-sm">
              {footerCategories.map((category) => (
                <li key={category.id}>
                  <Link
                    to={`/category/${getCategorySlug(category.name)}`}
                    className="text-gray-300 hover:text-primary transition-colors"
                  >
                    {category.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Contact */}
          <div>
            <h3 className="font-semibold text-lg mb-4">Contact Us</h3>
            <div className="space-y-3 text-sm">
              <div className="flex items-center">
                <MapPin className="w-4 h-4 text-primary mr-3" />
                <span className="text-gray-300">Khulna, Bangladesh</span>
              </div>
              <div className="flex items-center">
                <Mail className="w-4 h-4 text-primary mr-3" />
                <a href="mailto:support@kajhobe.bd" className="text-gray-300 hover:text-primary transition-colors">
                  support@kajhobe.bd
                </a>
              </div>
            </div>

            <div className="mt-6">
              <h4 className="font-medium mb-2">Areas We Serve</h4>
              <p className="text-xs text-gray-300 leading-relaxed">
                Sonadanga • Daulatpur • Khalishpur • Khan Jahan Ali • Boyra • Rupsha • All areas in Khulna
              </p>
            </div>
          </div>
        </div>

        <div className="border-t border-white/10 mt-8 pt-8">
          <div className="flex flex-col md:flex-row justify-between items-center">
            <p className="text-sm text-gray-300">
              © 2026 KajHobe. All rights reserved.
            </p>
            <div className="flex space-x-6 mt-4 md:mt-0">
              <Link to="/privacy" className="text-sm text-gray-300 hover:text-primary transition-colors">Privacy Policy</Link>
              <Link to="/terms" className="text-sm text-gray-300 hover:text-primary transition-colors">Terms of Service</Link>
              <Link to="/support" className="text-sm text-gray-300 hover:text-primary transition-colors">Support</Link>
            </div>
          </div>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
