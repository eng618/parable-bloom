'use client';

import { trackCtaClick } from '@/lib/analytics';
import Link from 'next/link';

export default function HeroActions() {
  return (
    <div className="flex flex-wrap gap-3">
      <Link
        href="https://parable-bloom.web.app/"
        target="_blank"
        rel="noopener noreferrer"
        onClick={() => trackCtaClick('Play on Web', 'hero', 'Available')}
        className="bg-brand hover:bg-brand/90 focus-visible:ring-brand/50 inline-flex items-center gap-2 rounded-full px-6 py-2.5 text-sm font-semibold text-white shadow-md transition-all duration-300 hover:-translate-y-0.5 hover:shadow-lg focus-visible:ring-2 focus-visible:outline-none"
      >
        🌐 Play on Web
      </Link>
      <Link
        href="https://play.google.com/store/apps/details?id=com.garciaericn.parable_bloom"
        target="_blank"
        rel="noopener noreferrer"
        onClick={() => trackCtaClick('Google Play', 'hero', 'Coming Soon')}
        className="border-border text-text-primary hover:border-brand/40 hover:bg-surface-alt inline-flex items-center gap-2 rounded-full border bg-white px-6 py-2.5 text-sm font-semibold transition-all duration-300 hover:-translate-y-0.5 hover:shadow-md"
      >
        🤖 Google Play
      </Link>
    </div>
  );
}
