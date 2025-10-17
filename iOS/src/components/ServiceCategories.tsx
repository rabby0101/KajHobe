
import { Card, CardContent } from "@/components/ui/card";
import { Wrench, Home, BookOpen, Monitor, Car, Scissors, Hammer, UtensilsCrossed, Smartphone, PartyPopper } from "lucide-react";
import { Link } from "react-router-dom";
import { useJobs } from "@/hooks/useJobs";

const categories = [
  {
    id: 1,
    name: "Home Repair & Maintenance",
    bengali: "ঘর মেরামত ও রক্ষণাবেক্ষণ",
    icon: Wrench,
    slug: "home-repair-maintenance",
    color: "bg-blue-50 text-blue-600 dark:bg-blue-900/20 dark:text-blue-400"
  },
  {
    id: 2,
    name: "Home Services",
    bengali: "ঘরোয়া সেবা",
    icon: Home,
    slug: "home-services",
    color: "bg-green-50 text-green-600 dark:bg-green-900/20 dark:text-green-400"
  },
  {
    id: 3,
    name: "Education & Tutoring",
    bengali: "শিক্ষা ও গৃহশিক্ষকতা",
    icon: BookOpen,
    slug: "education-tutoring",
    color: "bg-purple-50 text-purple-600 dark:bg-purple-900/20 dark:text-purple-400"
  },
  {
    id: 4,
    name: "Technology & IT",
    bengali: "প্রযুক্তি ও আইটি",
    icon: Monitor,
    slug: "technology-it",
    color: "bg-indigo-50 text-indigo-600 dark:bg-indigo-900/20 dark:text-indigo-400"
  },
  {
    id: 5,
    name: "Automotive",
    bengali: "গাড়ি ও যানবাহন",
    icon: Car,
    slug: "automotive",
    color: "bg-red-50 text-red-600 dark:bg-red-900/20 dark:text-red-400"
  },
  {
    id: 6,
    name: "Personal Services",
    bengali: "ব্যক্তিগত সেবা",
    icon: Scissors,
    slug: "personal-services",
    color: "bg-pink-50 text-pink-600 dark:bg-pink-900/20 dark:text-pink-400"
  },
  {
    id: 7,
    name: "Construction & Renovation",
    bengali: "নির্মাণ ও সংস্কার",
    icon: Hammer,
    slug: "construction-renovation",
    color: "bg-orange-50 text-orange-600 dark:bg-orange-900/20 dark:text-orange-400"
  },
  {
    id: 8,
    name: "Food & Catering",
    bengali: "খাদ্য ও ক্যাটারিং",
    icon: UtensilsCrossed,
    slug: "food-catering",
    color: "bg-yellow-50 text-yellow-600 dark:bg-yellow-900/20 dark:text-yellow-400"
  },
  {
    id: 9,
    name: "Mobile & Electronics",
    bengali: "মোবাইল ও ইলেকট্রনিক্স",
    icon: Smartphone,
    slug: "mobile-electronics",
    color: "bg-teal-50 text-teal-600 dark:bg-teal-900/20 dark:text-teal-400"
  },
  {
    id: 10,
    name: "Events & Entertainment",
    bengali: "অনুষ্ঠান ও বিনোদন",
    icon: PartyPopper,
    slug: "events-entertainment",
    color: "bg-cyan-50 text-cyan-600 dark:bg-cyan-900/20 dark:text-cyan-400"
  }
];

const ServiceCategories = () => {
  const { data: jobs } = useJobs();

  const getCategoryJobCount = (categoryName: string) => {
    return jobs?.filter(job => job.category === categoryName).length || 0;
  };

  return (
    <section className="py-16 bg-muted/50">
      <div className="container mx-auto px-4">
        <div className="text-center mb-12">
          <h2 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
            Service Categories
          </h2>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
            Browse our wide range of services available in Khulna
          </p>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4 md:gap-6">
          {categories.map((category) => {
            const IconComponent = category.icon;
            const jobCount = getCategoryJobCount(category.name);
            
            return (
              <Link key={category.id} to={`/category/${category.slug}`}>
                <Card className="hover-scale cursor-pointer group border border-border hover:shadow-lg transition-all duration-300 bg-card hover:bg-accent/5">
                  <CardContent className="p-6 text-center">
                    <div className={`w-16 h-16 mx-auto mb-4 rounded-full flex items-center justify-center ${category.color} group-hover:scale-110 transition-transform duration-300`}>
                      <IconComponent className="w-8 h-8" />
                    </div>
                    <h3 className="font-semibold text-sm md:text-base text-foreground mb-1 leading-tight">
                      {category.name}
                    </h3>
                    <p className="text-xs text-muted-foreground bengali-text mb-2">
                      {category.bengali}
                    </p>
                    <span className="text-xs bg-primary/10 text-primary px-2 py-1 rounded-full">
                      {jobCount} jobs
                    </span>
                  </CardContent>
                </Card>
              </Link>
            );
          })}
        </div>
      </div>
    </section>
  );
};

export default ServiceCategories;
