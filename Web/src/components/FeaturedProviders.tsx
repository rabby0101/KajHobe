import { Card, CardContent } from "@/components/ui/card";
import { Sparkles } from "lucide-react";
import { useLanguage } from "@/contexts/LanguageContext";

const FeaturedProviders = () => {
  const { t } = useLanguage();

  return (
    <section className="py-16">
      <div className="container mx-auto px-4">
        <div className="mb-12 text-center">
          <h2 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
            {t('featuredProviders.title')}
          </h2>
          <p className="text-xl text-muted-foreground">
            {t('featuredProviders.subtitle')}
          </p>
        </div>

        {/* Placeholder until verified providers can be featured here. */}
        <Card className="mx-auto max-w-2xl border border-dashed border-border bg-muted/30">
          <CardContent className="flex flex-col items-center gap-4 p-12 text-center">
            <div className="flex h-14 w-14 items-center justify-center rounded-full bg-primary/10">
              <Sparkles className="h-7 w-7 text-primary" />
            </div>
            <h3 className="text-xl font-semibold text-foreground">{t('featuredProviders.comingSoon')}</h3>
            <p className="max-w-md text-muted-foreground">
              {t('featuredProviders.comingSoonDesc')}
            </p>
          </CardContent>
        </Card>
      </div>
    </section>
  );
};

export default FeaturedProviders;
