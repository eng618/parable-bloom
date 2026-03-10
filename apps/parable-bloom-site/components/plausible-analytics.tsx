'use client';

import Plausible from '@plausible-analytics/tracker';
import { usePathname, useSearchParams } from 'next/navigation';
import { useEffect } from 'react';

const plausibleDomain = process.env.NEXT_PUBLIC_PLAUSIBLE_DOMAIN ?? 'parable-bloom.pages.dev';
const plausibleEnabled = process.env.NEXT_PUBLIC_PLAUSIBLE_ENABLED === 'true';
const plausibleApiHost = process.env.NEXT_PUBLIC_PLAUSIBLE_ENDPOINT ?? 'https://stats.garciaericn.com/api/event';

const tracker =
  plausibleEnabled && plausibleDomain
    ? Plausible({
        domain: plausibleDomain,
        apiHost: plausibleApiHost,
      })
    : null;

export default function PlausibleAnalytics() {
  const pathname = usePathname();
  const searchParams = useSearchParams();

  useEffect(() => {
    if (!tracker) {
      return;
    }

    tracker.trackPageview();
  }, [pathname, searchParams]);

  return null;
}
