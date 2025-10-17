
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Star, MapPin, Clock, Award } from "lucide-react";

const featuredProviders = [
  {
    id: 1,
    name: "Md. Karim Uddin",
    profession: "Electrician",
    rating: 4.9,
    reviews: 127,
    completedJobs: 150,
    startingPrice: "৳300",
    location: "Sonadanga",
    responseTime: "Within 2 hours",
    verified: true,
    skills: ["Wiring", "Fan Installation", "LED Fitting"],
    avatar: `https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face`
  },
  {
    id: 2,
    name: "Fatema Begum",
    profession: "Home Tutor",
    rating: 4.8,
    reviews: 89,
    completedJobs: 95,
    startingPrice: "৳2500/month",
    location: "Daulatpur",
    responseTime: "Within 4 hours",
    verified: true,
    skills: ["Math", "English", "Science"],
    avatar: `https://images.unsplash.com/photo-1494790108755-2616b612b8d3?w=150&h=150&fit=crop&crop=face`
  },
  {
    id: 3,
    name: "Rakib Hasan",
    profession: "Plumber",
    rating: 4.7,
    reviews: 156,
    completedJobs: 180,
    startingPrice: "৳400",
    location: "Khalishpur",
    responseTime: "Within 1 hour",
    verified: true,
    skills: ["Pipe Repair", "Bathroom Fitting", "Water Pump"],
    avatar: `https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face`
  },
  {
    id: 4,
    name: "Shahina Akter",
    profession: "House Cleaner",
    rating: 4.9,
    reviews: 203,
    completedJobs: 220,
    startingPrice: "৳600",
    location: "Khan Jahan Ali",
    responseTime: "Within 3 hours",
    verified: true,
    skills: ["Deep Cleaning", "Kitchen Clean", "Bathroom Clean"],
    avatar: `https://images.unsplash.com/photo-1580489944761-15a19d654956?w=150&h=150&fit=crop&crop=face`
  }
];

const FeaturedProviders = () => {
  return (
    <section className="py-16">
      <div className="container mx-auto px-4">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-12">
          <div>
            <h2 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
              Featured Service Providers
            </h2>
            <p className="text-xl text-muted-foreground">
              Top-rated professionals trusted by the Khulna community
            </p>
          </div>
          <button className="mt-4 md:mt-0 text-primary hover:text-primary/80 font-medium">
            View All Providers →
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {featuredProviders.map((provider) => (
            <Card
              key={provider.id}
              className="hover-scale cursor-pointer group border border-border hover:shadow-lg transition-all duration-300"
            >
              <CardContent className="p-6">
                {/* Avatar and Verification */}
                <div className="relative mb-4">
                  <img
                    src={provider.avatar}
                    alt={provider.name}
                    className="w-16 h-16 rounded-full mx-auto object-cover"
                  />
                  {provider.verified && (
                    <div className="absolute -top-1 -right-1 w-6 h-6 bg-green-500 rounded-full flex items-center justify-center">
                      <Award className="w-3 h-3 text-white" />
                    </div>
                  )}
                </div>

                {/* Name and Profession */}
                <div className="text-center mb-4">
                  <h3 className="font-semibold text-lg text-foreground group-hover:text-primary transition-colors">
                    {provider.name}
                  </h3>
                  <p className="text-muted-foreground">{provider.profession}</p>
                </div>

                {/* Rating */}
                <div className="flex items-center justify-center mb-4">
                  <Star className="w-4 h-4 text-yellow-400 fill-current" />
                  <span className="ml-1 font-semibold">{provider.rating}</span>
                  <span className="ml-1 text-sm text-muted-foreground">
                    ({provider.reviews} reviews)
                  </span>
                </div>

                {/* Skills */}
                <div className="flex flex-wrap gap-1 mb-4">
                  {provider.skills.slice(0, 2).map((skill) => (
                    <Badge key={skill} variant="secondary" className="text-xs">
                      {skill}
                    </Badge>
                  ))}
                  {provider.skills.length > 2 && (
                    <Badge variant="outline" className="text-xs">
                      +{provider.skills.length - 2}
                    </Badge>
                  )}
                </div>

                {/* Details */}
                <div className="space-y-2 mb-4 text-sm">
                  <div className="flex items-center text-muted-foreground">
                    <MapPin className="w-3 h-3 mr-2" />
                    <span>{provider.location}</span>
                  </div>
                  <div className="flex items-center text-muted-foreground">
                    <Clock className="w-3 h-3 mr-2" />
                    <span>{provider.responseTime}</span>
                  </div>
                </div>

                {/* Starting Price */}
                <div className="text-center mb-4">
                  <span className="text-lg font-bold text-primary">
                    Starting {provider.startingPrice}
                  </span>
                </div>

                {/* Contact Button */}
                <button className="w-full bg-primary text-primary-foreground py-2 px-4 rounded-md hover:bg-primary/90 transition-colors text-sm font-medium">
                  Contact Now
                </button>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
};

export default FeaturedProviders;
