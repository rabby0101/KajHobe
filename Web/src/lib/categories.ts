// Service Categories - Matching iOS HardcodedServiceCategory
export interface ServiceCategory {
  id: string;
  name: string;
  bengaliName: string;
  icon: string;
  color: string;
}

export const serviceCategories: ServiceCategory[] = [
  {
    id: "1",
    name: "Home Repair & Maintenance",
    bengaliName: "ঘর মেরামত ও রক্ষণাবেক্ষণ",
    icon: "🔧",
    color: "blue"
  },
  {
    id: "2",
    name: "Home Services",
    bengaliName: "ঘরোয়া সেবা",
    icon: "🏠",
    color: "green"
  },
  {
    id: "3",
    name: "Education & Tutoring",
    bengaliName: "শিক্ষা ও গৃহশিক্ষকতা",
    icon: "📚",
    color: "purple"
  },
  {
    id: "4",
    name: "Technology & IT",
    bengaliName: "প্রযুক্তি ও আইটি",
    icon: "💻",
    color: "indigo"
  },
  {
    id: "5",
    name: "Automotive",
    bengaliName: "গাড়ি ও যানবাহন",
    icon: "🚗",
    color: "red"
  },
  {
    id: "6",
    name: "Personal Services",
    bengaliName: "ব্যক্তিগত সেবা",
    icon: "✂️",
    color: "pink"
  },
  {
    id: "7",
    name: "Construction & Renovation",
    bengaliName: "নির্মাণ ও সংস্কার",
    icon: "🔨",
    color: "orange"
  },
  {
    id: "8",
    name: "Food & Catering",
    bengaliName: "খাদ্য ও ক্যাটারিং",
    icon: "🍽️",
    color: "yellow"
  },
  {
    id: "9",
    name: "Mobile & Electronics",
    bengaliName: "মোবাইল ও ইলেকট্রনিক্স",
    icon: "📱",
    color: "teal"
  },
  {
    id: "10",
    name: "Events & Entertainment",
    bengaliName: "অনুষ্ঠান ও বিনোদন",
    icon: "🎉",
    color: "cyan"
  }
];

export const getCategoryNames = (): string[] => {
  return serviceCategories.map(category => category.name);
};

export const getCategory = (name: string): ServiceCategory | undefined => {
  return serviceCategories.find(category => category.name === name);
};

// Color mapping for Tailwind classes
export const getColorClasses = (color: string) => {
  const colorMap = {
    blue: {
      bg: 'bg-blue-500',
      bgLight: 'bg-blue-50',
      text: 'text-blue-600',
      border: 'border-blue-200',
      hover: 'hover:bg-blue-100'
    },
    green: {
      bg: 'bg-green-500',
      bgLight: 'bg-green-50',
      text: 'text-green-600',
      border: 'border-green-200',
      hover: 'hover:bg-green-100'
    },
    purple: {
      bg: 'bg-purple-500',
      bgLight: 'bg-purple-50',
      text: 'text-purple-600',
      border: 'border-purple-200',
      hover: 'hover:bg-purple-100'
    },
    indigo: {
      bg: 'bg-indigo-500',
      bgLight: 'bg-indigo-50',
      text: 'text-indigo-600',
      border: 'border-indigo-200',
      hover: 'hover:bg-indigo-100'
    },
    red: {
      bg: 'bg-red-500',
      bgLight: 'bg-red-50',
      text: 'text-red-600',
      border: 'border-red-200',
      hover: 'hover:bg-red-100'
    },
    pink: {
      bg: 'bg-pink-500',
      bgLight: 'bg-pink-50',
      text: 'text-pink-600',
      border: 'border-pink-200',
      hover: 'hover:bg-pink-100'
    },
    orange: {
      bg: 'bg-orange-500',
      bgLight: 'bg-orange-50',
      text: 'text-orange-600',
      border: 'border-orange-200',
      hover: 'hover:bg-orange-100'
    },
    yellow: {
      bg: 'bg-yellow-500',
      bgLight: 'bg-yellow-50',
      text: 'text-yellow-600',
      border: 'border-yellow-200',
      hover: 'hover:bg-yellow-100'
    },
    teal: {
      bg: 'bg-teal-500',
      bgLight: 'bg-teal-50',
      text: 'text-teal-600',
      border: 'border-teal-200',
      hover: 'hover:bg-teal-100'
    },
    cyan: {
      bg: 'bg-cyan-500',
      bgLight: 'bg-cyan-50',
      text: 'text-cyan-600',
      border: 'border-cyan-200',
      hover: 'hover:bg-cyan-100'
    }
  };
  
  return colorMap[color as keyof typeof colorMap] || colorMap.blue;
};