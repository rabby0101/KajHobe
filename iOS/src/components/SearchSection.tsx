import { Search } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";

const SearchSection = () => {
  return (
    <section className="py-12 bg-gradient-to-r from-blue-50 to-indigo-100 dark:from-blue-900/20 dark:to-indigo-900/20">
      <div className="container mx-auto px-4">
        <div className="max-w-2xl mx-auto text-center">
          <h2 className="text-3xl font-bold mb-4 text-gray-900 dark:text-white">
            Find Services in Khulna
          </h2>
          <p className="text-lg text-gray-600 dark:text-gray-300 mb-8">
            Connect with skilled professionals and service providers in your area
          </p>
          <div className="flex gap-2 max-w-lg mx-auto">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
              <Input 
                placeholder="Search for services..." 
                className="pl-10 h-12"
              />
            </div>
            <Button size="lg" className="h-12 px-8">
              Search
            </Button>
          </div>
        </div>
      </div>
    </section>
  );
};

export default SearchSection;