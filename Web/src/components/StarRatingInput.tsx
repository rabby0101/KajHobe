import { useState } from 'react';
import { Star } from 'lucide-react';
import { cn } from '@/lib/utils';

interface StarRatingInputProps {
  value: number;
  onChange: (rating: number) => void;
  size?: number;
  readOnly?: boolean;
}

/** Tappable 1–5 star input (parity with iOS StarRatingInput). */
export default function StarRatingInput({ value, onChange, size = 36, readOnly = false }: StarRatingInputProps) {
  const [hover, setHover] = useState(0);
  const active = hover || value;

  return (
    <div className="flex items-center justify-center gap-2" role="radiogroup" aria-label="Star rating">
      {[1, 2, 3, 4, 5].map((star) => (
        <button
          key={star}
          type="button"
          disabled={readOnly}
          aria-label={`${star} star${star > 1 ? 's' : ''}`}
          aria-checked={value === star}
          role="radio"
          className={cn('transition-transform', !readOnly && 'hover:scale-110', readOnly && 'cursor-default')}
          onMouseEnter={() => !readOnly && setHover(star)}
          onMouseLeave={() => !readOnly && setHover(0)}
          onClick={() => !readOnly && onChange(star)}
        >
          <Star
            style={{ width: size, height: size }}
            className={cn(
              'transition-colors',
              star <= active ? 'fill-yellow-400 text-yellow-400' : 'text-muted-foreground/40'
            )}
          />
        </button>
      ))}
    </div>
  );
}
