
import { Facebook, Instagram, Mail, Phone, MapPin } from "lucide-react";

const Footer = () => {
  return (
    <footer className="bg-foreground text-background">
      <div className="container mx-auto px-4 py-12">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
          {/* Company Info */}
          <div>
            <div className="flex items-center space-x-2 mb-4">
              <div className="w-8 h-8 bg-primary rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-sm">KS</span>
              </div>
              <span className="font-bold text-xl">Khulna Services</span>
            </div>
            <p className="text-sm text-gray-300 mb-4 leading-relaxed">
              Connecting Khulna residents with trusted local service providers. 
              Your one-stop solution for all service needs.
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
              <li><a href="#" className="text-gray-300 hover:text-primary transition-colors">Browse Services</a></li>
              <li><a href="#" className="text-gray-300 hover:text-primary transition-colors">Post a Job</a></li>
              <li><a href="#" className="text-gray-300 hover:text-primary transition-colors">Become a Provider</a></li>
              <li><a href="#" className="text-gray-300 hover:text-primary transition-colors">How It Works</a></li>
              <li><a href="#" className="text-gray-300 hover:text-primary transition-colors">Safety Guidelines</a></li>
            </ul>
          </div>

          {/* Categories */}
          <div>
            <h3 className="font-semibold text-lg mb-4">Popular Categories</h3>
            <ul className="space-y-2 text-sm">
              <li><a href="#" className="text-gray-300 hover:text-primary transition-colors">Home Repair</a></li>
              <li><a href="#" className="text-gray-300 hover:text-primary transition-colors">Education & Tutoring</a></li>
              <li><a href="#" className="text-gray-300 hover:text-primary transition-colors">Technology & IT</a></li>
              <li><a href="#" className="text-gray-300 hover:text-primary transition-colors">Personal Services</a></li>
              <li><a href="#" className="text-gray-300 hover:text-primary transition-colors">Construction</a></li>
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
                <Phone className="w-4 h-4 text-primary mr-3" />
                <span className="text-gray-300">+880 1XXX-XXXXXX</span>
              </div>
              <div className="flex items-center">
                <Mail className="w-4 h-4 text-primary mr-3" />
                <span className="text-gray-300">info@khulnaservices.com</span>
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

        <div className="border-t border-gray-700 mt-8 pt-8">
          <div className="flex flex-col md:flex-row justify-between items-center">
            <p className="text-sm text-gray-300">
              © 2024 Khulna Services Hub. All rights reserved.
            </p>
            <div className="flex space-x-6 mt-4 md:mt-0">
              <a href="#" className="text-sm text-gray-300 hover:text-primary transition-colors">Privacy Policy</a>
              <a href="#" className="text-sm text-gray-300 hover:text-primary transition-colors">Terms of Service</a>
              <a href="#" className="text-sm text-gray-300 hover:text-primary transition-colors">Support</a>
            </div>
          </div>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
