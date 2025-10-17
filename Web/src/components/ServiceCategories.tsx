
import { Card, CardContent } from "@/components/ui/card";
import { Link } from "react-router-dom";
import { useJobs } from "@/hooks/useJobs";
import { serviceCategories, getColorClasses } from "@/lib/categories";

const ServiceCategories = () => {
  const { data: jobs } = useJobs();

  const getCategoryJobCount = (categoryName: string) => {
    return jobs?.filter(job => 
      job.category.toLowerCase().includes(categoryName.toLowerCase())
    ).length || 0;
  };

  const getCategorySlug = (categoryName: string) => {
    return categoryName.toLowerCase()
      .replace(/\s+/g, '-')
      .replace(/&/g, 'and')
      .replace(/[^\w-]/g, '');
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
          {serviceCategories.map((category) => {
            const jobCount = getCategoryJobCount(category.name);
            const colorClasses = getColorClasses(category.color);
            const slug = getCategorySlug(category.name);
            
            return (
              <Link key={category.id} to={`/category/${slug}`}>
                <Card className="hover-scale cursor-pointer group border border-border hover:shadow-lg transition-all duration-300 bg-card hover:bg-accent/5">
                  <CardContent className="p-6 text-center">
                    <div className={`w-16 h-16 mx-auto mb-4 rounded-full flex items-center justify-center ${colorClasses.bgLight} group-hover:scale-110 transition-transform duration-300`}>
                      <span className="text-2xl">{category.icon}</span>
                    </div>
                    <h3 className="font-semibold text-sm md:text-base text-foreground mb-1 leading-tight">
                      {category.name}
                    </h3>
                    <p className="text-xs text-muted-foreground bengali-text mb-2">
                      {category.bengaliName}
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
