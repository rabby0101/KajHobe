
import { Card, CardContent } from "@/components/ui/card";
import { Plus, MessageCircle, UserCheck, Star } from "lucide-react";
import { useLanguage } from "@/contexts/LanguageContext";

const stepMeta = [
  { step: 1, icon: Plus, titleKey: "howItWorks.step1.title", descKey: "howItWorks.step1.desc", color: "bg-blue-50 text-blue-600" },
  { step: 2, icon: MessageCircle, titleKey: "howItWorks.step2.title", descKey: "howItWorks.step2.desc", color: "bg-green-50 text-green-600" },
  { step: 3, icon: UserCheck, titleKey: "howItWorks.step3.title", descKey: "howItWorks.step3.desc", color: "bg-orange-50 text-orange-600" },
  { step: 4, icon: Star, titleKey: "howItWorks.step4.title", descKey: "howItWorks.step4.desc", color: "bg-purple-50 text-purple-600" },
];

const HowItWorks = () => {
  const { t } = useLanguage();
  const steps = stepMeta.map((s) => ({ ...s, title: t(s.titleKey), description: t(s.descKey) }));

  return (
    <section id="how-it-works" className="py-16 bg-muted/50">
      <div className="container mx-auto px-4">
        <div className="text-center mb-12">
          <h2 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
            {t('howItWorks.title')}
          </h2>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
            {t('howItWorks.subtitle')}
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
