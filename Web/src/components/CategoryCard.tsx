import React from 'react';
import { Badge } from '@/components/ui/badge';
import { ServiceCategory, getColorClasses } from '@/lib/categories';
import { useLanguage } from '@/contexts/LanguageContext';

interface CategoryCardProps {
  category: ServiceCategory;
  jobCount: number;
  isSelected: boolean;
  onClick: () => void;
}

/** Selectable service-category card used on the home and browse pages. */
const CategoryCard: React.FC<CategoryCardProps> = ({ category, jobCount, isSelected, onClick }) => {
  const { language, t } = useLanguage();
  const colorClasses = getColorClasses(category.color);
  // In Bangla, lead with the Bengali name; otherwise lead with English.
  const primary = language === 'bn' ? category.bengaliName : category.name;
  const secondary = language === 'bn' ? category.name : category.bengaliName;

  return (
    <button
      onClick={onClick}
      className={`
        flex-none p-4 rounded-xl border-2 transition-all duration-200 min-w-[120px] w-[120px] h-[140px]
        ${isSelected
          ? `${colorClasses.bgLight} ${colorClasses.border}`
          : 'bg-muted/50 border-transparent hover:bg-muted'
        }
      `}
    >
      <div className="flex flex-col items-center space-y-2 h-full">
        <div className="text-3xl">{category.icon}</div>
        <div className="text-center flex-1">
          <h3 className="font-semibold text-sm leading-tight line-clamp-2">{primary}</h3>
          <p className="text-xs text-muted-foreground mt-1 line-clamp-1">{secondary}</p>
        </div>
        <Badge variant="secondary" className={`text-xs ${isSelected ? colorClasses.text : ''}`}>
          {jobCount} {t('common.jobsCount')}
        </Badge>
      </div>
    </button>
  );
};

export default CategoryCard;
