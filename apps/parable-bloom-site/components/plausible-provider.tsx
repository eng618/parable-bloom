'use client';

import { useEffect } from 'react';

const plausibleDomain = process.env.NEXT_PUBLIC_PLAUSIBLE_DOMAIN ?? 'garciaericn.com';
const plausibleEndpoint = process.env.NEXT_PUBLIC_PLAUSIBLE_ENDPOINT ?? 'https://stats.garciaericn.com/api/event';

export default function PlausibleProvider() {
  useEffect(() => {
    const initPlausible = async () => {
      if (window.location.hostname === 'localhost') {
        return;
      }

      if (window.localStorage.getItem('plausible_ignore') === 'true') {
        return;
      }

      const plausibleModule = await import('@plausible-analytics/tracker');
      const init = plausibleModule.init ?? plausibleModule.default?.init;

      if (!init) {
        return;
      }

      init({
        domain: plausibleDomain,
        endpoint: plausibleEndpoint,
        autoCapturePageviews: true,
        formSubmissions: true,
        outboundLinks: true,
        fileDownloads: true,
        customProperties: () => ({
          page_title: document.querySelector('h1')?.textContent ?? document.title,
        }),
      });
    };

    void initPlausible();
  }, []);

  return null;
}
