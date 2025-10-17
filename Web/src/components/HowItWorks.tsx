
import { Card, CardContent } from "@/components/ui/card";
import { Plus, MessageCircle, UserCheck, Star } from "lucide-react";

const steps = [
  {
    step: 1,
    icon: Plus,
    title: "Post Your Need",
    description: "Describe what service you need with details, budget, and timeline",
    color: "bg-blue-50 text-blue-600"
  },
  {
    step: 2,
    icon: MessageCircle,
    title: "Get Proposals",
    description: "Qualified service providers will contact you with quotes and offers",
    color: "bg-green-50 text-green-600"
  },
  {
    step: 3,
    icon: UserCheck,
    title: "Choose & Connect",
    description: "Review profiles, ratings, and select the best provider for your job",
    color: "bg-orange-50 text-orange-600"
  },
  {
    step: 4,
    icon: Star,
    title: "Get It Done",
    description: "Complete the service and rate your experience to help others",
    color: "bg-purple-50 text-purple-600"
  }
];

const HowItWorks = () => {
  return (
    <section className="py-16 bg-gray-50">
      <div className="container mx-auto px-4">
        <div className="text-center mb-12">
          <h2 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
            How It Works
          </h2>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
            Getting your service needs fulfilled is simple and straightforward
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
          {steps.map((step, index) => {
            const IconComponent = step.icon;
            return (
              <div key={step.step} className="relative">
                <Card className="text-center border-0 shadow-sm hover:shadow-lg transition-shadow duration-300">
                  <CardContent className="p-8">
                    <div className={`w-16 h-16 mx-auto mb-6 rounded-full flex items-center justify-center ${step.color}`}>
                      <IconComponent className="w-8 h-8" />
                    </div>
                    <div className="mb-4">
                      <span className="inline-flex items-center justify-center w-8 h-8 bg-primary text-primary-foreground rounded-full text-sm font-bold mb-3">
                        {step.step}
                      </span>
                    </div>
                    <h3 className="text-xl font-semibold text-foreground mb-3">
                      {step.title}
                    </h3>
                    <p className="text-muted-foreground leading-relaxed">
                      {step.description}
                    </p>
                  </CardContent>
                </Card>
                
                {/* Arrow for desktop */}
                {index < steps.length - 1 && (
                  <div className="hidden lg:block absolute top-1/2 -right-4 transform -translate-y-1/2 z-10">
                    <div className="w-8 h-0.5 bg-primary"></div>
                    <div className="absolute right-0 top-1/2 transform -translate-y-1/2 w-0 h-0 border-l-4 border-l-primary border-t-2 border-t-transparent border-b-2 border-b-transparent"></div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
};

export default HowItWorks;
