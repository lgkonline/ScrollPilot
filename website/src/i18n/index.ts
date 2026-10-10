import de from './de.json';

export type Locale = 'en' | 'de';
export type TranslationKey = keyof typeof de;

// English source strings are the keys, so missing German translations are type errors.
export function translator(locale: Locale) {
  return (key: TranslationKey): string => locale === 'de' ? de[key] : key;
}
