// Avro Phonetic transliteration engine (Banglish -> Bangla).
//
// Original implementation of the well-known Avro Phonetic algorithm. The rule
// table in `rules.json` is the MIT-licensed avrodict (jsAvroPhonetic by Rifat
// Nabi / OmicronLab). This parser is an independent port of the documented
// algorithm; see https://www.omicronlab.com for the method itself.

import avrodict from './rules.json';

interface Match {
  type: 'prefix' | 'suffix';
  scope: string;
  value?: string;
}
interface Rule {
  matches: Match[];
  replace: string;
}
interface Pattern {
  find: string;
  replace: string;
  rules?: Rule[];
}

const data = avrodict.data;

// Longest finds must win, so sort each group by find length descending. Only
// one find of a given length can ever match a given cursor, so this is a safe,
// stable ordering that guarantees greedy longest-match.
const byFindLenDesc = (a: Pattern, b: Pattern) => b.find.length - a.find.length;
const PATTERNS = (data.patterns as Pattern[]).slice().sort(byFindLenDesc);
const NON_RULE_PATTERNS = PATTERNS.filter((p) => !p.rules);
const RULE_PATTERNS = PATTERNS.filter((p) => p.rules);

const VOWELS = data.vowel;
const CONSONANTS = data.consonant;
const CASE_SENSITIVES = data.casesensitive;

const isVowel = (c: string) => VOWELS.indexOf(c.toLowerCase()) !== -1;
const isConsonant = (c: string) => CONSONANTS.indexOf(c.toLowerCase()) !== -1;
const isPunctuation = (c: string) => !isVowel(c) && !isConsonant(c);
const isCaseSensitive = (c: string) => CASE_SENSITIVES.indexOf(c.toLowerCase()) !== -1;

const isExact = (
  needle: string,
  haystack: string,
  start: number,
  end: number,
  not: boolean,
): boolean =>
  (start >= 0 && end <= haystack.length && haystack.substring(start, end) === needle) !== not;

// Case-sensitive characters keep their case; everything else is lowercased so
// the phonetic comparison is predictable.
function fixStringCase(text: string): string {
  let fixed = '';
  for (const c of text) fixed += isCaseSensitive(c) ? c : c.toLowerCase();
  return fixed;
}

function findFirstMatch(fixed: string, cur: number, patterns: Pattern[]): Pattern | null {
  for (const p of patterns) {
    const end = cur + p.find.length;
    if (end <= fixed.length && fixed.substring(cur, end) === p.find) return p;
  }
  return null;
}

function processMatch(match: Match, fixed: string, cur: number, curEnd: number): boolean {
  const negative = match.scope.startsWith('!');
  const scope = negative ? match.scope.slice(1) : match.scope;
  const chk = match.type === 'prefix' ? cur - 1 : curEnd;

  switch (scope) {
    case 'punctuation': {
      const cond =
        (chk < 0 && match.type === 'prefix') ||
        (chk >= fixed.length && match.type === 'suffix') ||
        isPunctuation(fixed[chk]);
      return cond !== negative;
    }
    case 'vowel': {
      const inRange =
        (chk >= 0 && match.type === 'prefix') || (chk < fixed.length && match.type === 'suffix');
      const cond = inRange && isVowel(fixed[chk]);
      return cond !== negative;
    }
    case 'consonant': {
      const inRange =
        (chk >= 0 && match.type === 'prefix') || (chk < fixed.length && match.type === 'suffix');
      const cond = inRange && isConsonant(fixed[chk]);
      return cond !== negative;
    }
    case 'exact': {
      const value = match.value ?? '';
      let start: number;
      let end: number;
      if (match.type === 'prefix') {
        start = cur - value.length;
        end = cur;
      } else {
        start = curEnd;
        end = curEnd + value.length;
      }
      return isExact(value, fixed, start, end, negative);
    }
    default:
      return false;
  }
}

function processRules(rules: Rule[], fixed: string, cur: number, curEnd: number): string | null {
  for (const rule of rules) {
    let matched = true;
    for (const match of rule.matches) {
      if (!processMatch(match, fixed, cur, curEnd)) {
        matched = false;
        break;
      }
    }
    if (matched) return rule.replace;
  }
  return null;
}

/** Transliterate a Banglish string into Bangla using Avro Phonetic rules. */
export function transliterate(text: string): string {
  const fixed = fixStringCase(text);
  let output = '';
  let curEnd = 0;

  for (let cur = 0; cur < fixed.length; cur++) {
    if (cur < curEnd) continue; // already consumed by a previous match

    // Non-rule patterns take priority over rule patterns (matches reference).
    const nonRule = findFirstMatch(fixed, cur, NON_RULE_PATTERNS);
    if (nonRule) {
      output += nonRule.replace;
      curEnd = cur + nonRule.find.length;
      continue;
    }

    const rulePattern = findFirstMatch(fixed, cur, RULE_PATTERNS);
    if (rulePattern && rulePattern.rules) {
      curEnd = cur + rulePattern.find.length;
      const replaced = processRules(rulePattern.rules, fixed, cur, curEnd);
      output += replaced !== null ? replaced : rulePattern.replace;
      continue;
    }

    output += fixed[cur];
    curEnd = cur + 1;
  }

  return output;
}

/**
 * Transliterate only the final, still-being-typed word of `text`, leaving any
 * text before the last word boundary untouched. Useful for live per-word
 * conversion in an input field where earlier words are already in Bangla.
 */
export function transliterateLastWord(text: string): string {
  const m = text.match(/[A-Za-z]+$/);
  if (!m) return text;
  const word = m[0];
  const head = text.slice(0, text.length - word.length);
  return head + transliterate(word);
}
