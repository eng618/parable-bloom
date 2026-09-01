'use client';

import { trackCtaClick } from '@/lib/analytics';
import { Button } from '@gv-tech/ui-web/button';
import Link from 'next/link';

export default function HeroActions() {
  return (
    <div className="flex flex-col flex-wrap gap-3 pt-2 sm:flex-row">
      <Button
        asChild
        size="lg"
        className="bg-brand hover:bg-brand/90 w-full rounded-full text-white shadow-md transition-all duration-300 hover:-translate-y-0.5 hover:shadow-lg sm:w-auto"
      >
        <Link
          href="https://parable-bloom.web.app/"
          target="_blank"
          rel="noopener noreferrer"
          onClick={() => trackCtaClick('Play on Web', 'hero', 'Available')}
        >
          🌐 Play on Web
        </Link>
      </Button>

      <Button
        asChild
        variant="outline"
        size="lg"
        className="border-border bg-card/80 hover:bg-surface-alt dark:hover:bg-muted text-foreground w-full rounded-full transition-all duration-300 hover:-translate-y-0.5 hover:shadow-md sm:w-auto"
      >
        <Link
          href="https://play.google.com/store/apps/details?id=com.garciaericn.parable_bloom"
          target="_blank"
          rel="noopener noreferrer"
          onClick={() => trackCtaClick('Google Play', 'hero', 'Coming Soon')}
        >
          🤖 Google Play
        </Link>
      </Button>
    </div>
  );
}
