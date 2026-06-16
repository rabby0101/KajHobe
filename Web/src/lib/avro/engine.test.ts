import { describe, expect, it } from 'vitest';
import { transliterate, transliterateLastWord } from './engine';

// Compare under NFC so precomposed vs decomposed forms (e.g. য় U+09DF) match.
const nfc = (s: string) => s.normalize('NFC');

// Shared cross-platform word pairs — keep in sync with the iOS/Android tests so
// all three Avro ports stay consistent. Values are the canonical Avro Phonetic
// outputs (Bengali consonants carry an inherent "o", so e.g. `bhalo` -> ভাল and
// ধন্যবাদ is typed `dhonyobad`).
const PAIRS: Array<[string, string]> = [
  ['ami', 'আমি'],
  ['kaj', 'কাজ'],
  ['kemon', 'কেমন'],
  ['bangla', 'বাংলা'],
  ['banglay', 'বাংলায়'],
  ['bhalo', 'ভাল'],
  ['dhonyobad', 'ধন্যবাদ'],
];

describe('avro transliterate', () => {
  for (const [input, expected] of PAIRS) {
    it(`${input} -> ${expected}`, () => {
      expect(nfc(transliterate(input))).toBe(nfc(expected));
    });
  }

  it('transliterates a full sentence (pyAvroPhonetic reference case)', () => {
    expect(nfc(transliterate('ami banglay gan gai'))).toBe(nfc('আমি বাংলায় গান গাই'));
  });

  it('only transliterates the last word', () => {
    expect(nfc(transliterateLastWord('আমি kaj'))).toBe(nfc('আমি কাজ'));
    expect(transliterateLastWord('আমি ')).toBe('আমি ');
  });
});
