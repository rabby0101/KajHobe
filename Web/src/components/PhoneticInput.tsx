import * as React from 'react';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { cn } from '@/lib/utils';
import { useLanguage } from '@/contexts/LanguageContext';
import { transliterate } from '@/lib/avro/engine';

// Convert every Latin word that is *followed by* a non-letter (i.e. a completed
// word), leaving a still-being-typed trailing Latin run untouched. Already-Bangla
// words contain no [A-Za-z] runs, so they are never re-converted.
const convertCompletedWords = (raw: string) =>
  raw.replace(/[A-Za-z]+(?=[^A-Za-z])/g, (w) => transliterate(w));

// Convert everything, including a trailing in-progress word (used on blur).
const convertAll = (raw: string) => raw.replace(/[A-Za-z]+/g, (w) => transliterate(w));

interface PhoneticToggleProps {
  enabled: boolean;
  onToggle: () => void;
  className?: string;
}

/** Small অ ⇄ A button that flips phonetic Bangla typing on/off. */
const PhoneticToggle: React.FC<PhoneticToggleProps> = ({ enabled, onToggle, className }) => (
  <button
    type="button"
    tabIndex={-1}
    onMouseDown={(e) => e.preventDefault()} // keep focus in the field
    onClick={onToggle}
    aria-pressed={enabled}
    title={enabled ? 'Bangla phonetic typing on' : 'Bangla phonetic typing off'}
    className={cn(
      'flex h-6 w-6 items-center justify-center rounded-md border text-sm font-semibold transition-colors',
      enabled
        ? 'border-primary bg-primary/10 text-primary'
        : 'border-input bg-muted text-muted-foreground hover:bg-muted/70',
      className,
    )}
  >
    {enabled ? 'অ' : 'A'}
  </button>
);

function usePhonetic(value: string, onChange: (value: string) => void) {
  const { language } = useLanguage();
  // Default phonetic typing ON when the app is in Bangla.
  const [enabled, setEnabled] = React.useState(language === 'bn');
  const caretToEnd = React.useRef(false);

  const handleChange = React.useCallback(
    (raw: string) => {
      if (!enabled) {
        onChange(raw);
        return;
      }
      const converted = convertCompletedWords(raw);
      caretToEnd.current = converted !== raw;
      onChange(converted);
    },
    [enabled, onChange],
  );

  const handleBlur = React.useCallback(() => {
    if (!enabled) return;
    const converted = convertAll(value);
    if (converted !== value) onChange(converted);
  }, [enabled, value, onChange]);

  return { enabled, setEnabled, handleChange, handleBlur, caretToEnd };
}

export interface PhoneticInputProps
  extends Omit<React.ComponentProps<'input'>, 'onChange' | 'value'> {
  value: string;
  onChange: (value: string) => void;
  containerClassName?: string;
}

/** Text input with optional in-app Avro-style Bangla phonetic typing. */
export const PhoneticInput = React.forwardRef<HTMLInputElement, PhoneticInputProps>(
  ({ value, onChange, className, containerClassName, ...props }, forwardedRef) => {
    const innerRef = React.useRef<HTMLInputElement>(null);
    React.useImperativeHandle(forwardedRef, () => innerRef.current as HTMLInputElement);
    const { enabled, setEnabled, handleChange, handleBlur, caretToEnd } = usePhonetic(value, onChange);

    React.useEffect(() => {
      if (caretToEnd.current && innerRef.current) {
        const end = innerRef.current.value.length;
        innerRef.current.setSelectionRange(end, end);
        caretToEnd.current = false;
      }
    });

    return (
      <div className={cn('relative', containerClassName)}>
        <Input
          ref={innerRef}
          value={value}
          onChange={(e) => handleChange(e.target.value)}
          onBlur={handleBlur}
          className={cn('pr-9', className)}
          {...props}
        />
        <PhoneticToggle
          enabled={enabled}
          onToggle={() => setEnabled((v) => !v)}
          className="absolute right-2 top-1/2 -translate-y-1/2"
        />
      </div>
    );
  },
);
PhoneticInput.displayName = 'PhoneticInput';

export interface PhoneticTextareaProps
  extends Omit<React.ComponentProps<'textarea'>, 'onChange' | 'value'> {
  value: string;
  onChange: (value: string) => void;
  containerClassName?: string;
}

/** Multiline text input with optional in-app Avro-style Bangla phonetic typing. */
export const PhoneticTextarea = React.forwardRef<HTMLTextAreaElement, PhoneticTextareaProps>(
  ({ value, onChange, className, containerClassName, ...props }, forwardedRef) => {
    const innerRef = React.useRef<HTMLTextAreaElement>(null);
    React.useImperativeHandle(forwardedRef, () => innerRef.current as HTMLTextAreaElement);
    const { enabled, setEnabled, handleChange, handleBlur, caretToEnd } = usePhonetic(value, onChange);

    React.useEffect(() => {
      if (caretToEnd.current && innerRef.current) {
        const end = innerRef.current.value.length;
        innerRef.current.setSelectionRange(end, end);
        caretToEnd.current = false;
      }
    });

    return (
      <div className={cn('relative', containerClassName)}>
        <Textarea
          ref={innerRef}
          value={value}
          onChange={(e) => handleChange(e.target.value)}
          onBlur={handleBlur}
          className={cn('pr-9', className)}
          {...props}
        />
        <PhoneticToggle
          enabled={enabled}
          onToggle={() => setEnabled((v) => !v)}
          className="absolute right-2 top-2"
        />
      </div>
    );
  },
);
PhoneticTextarea.displayName = 'PhoneticTextarea';
