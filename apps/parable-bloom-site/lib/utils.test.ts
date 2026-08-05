import { describe, expect, it } from 'bun:test';
import { cn } from './utils';

describe('cn utility', () => {
  it('combines class names correctly', () => {
    expect(cn('class1', 'class2')).toBe('class1 class2');
  });

  it('handles conditional class names with boolean/falsy values', () => {
    expect(cn('class1', true && 'class2', false && 'class3', null, undefined)).toBe('class1 class2');
  });

  it('handles objects with conditional classes', () => {
    expect(cn({ class1: true, class2: false, class3: true })).toBe('class1 class3');
  });

  it('merges tailwind classes correctly using tailwind-merge', () => {
    // twMerge should override px-2 and py-1 when p-4 is passed
    expect(cn('px-2 py-1', 'p-4')).toBe('p-4');
  });

  it('handles empty inputs and returns an empty string', () => {
    expect(cn()).toBe('');
  });

  it('handles arrays of classes', () => {
    expect(cn(['class1', 'class2'], ['class3'])).toBe('class1 class2 class3');
  });
});
