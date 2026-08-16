'use client';

import { OpenPanelComponent } from '@openpanel/nextjs';
import { useEffect, useState } from 'react';

const openpanelClientId = process.env.NEXT_PUBLIC_OPENPANEL_CLIENT_ID ?? '57d65b3c-ceae-4dec-a729-8282740ba273';
const openpanelApiUrl = process.env.NEXT_PUBLIC_OPENPANEL_API_URL ?? 'https://openpanel.gventureshq.com/api';

export default function OpenpanelProvider() {
  const [isEnabled, setIsEnabled] = useState(false);

  useEffect(() => {
    if (typeof window === 'undefined') {
      return;
    }

    if (window.location.hostname === 'localhost') {
      return;
    }

    const isOptedOut =
      window.localStorage.getItem('openpanel_ignore') === 'true' ||
      window.localStorage.getItem('plausible_ignore') === 'true';

    if (!isOptedOut && openpanelClientId) {
      setIsEnabled(true);
    }
  }, []);

  if (!isEnabled) {
    return null;
  }

  return (
    <OpenPanelComponent
      clientId={openpanelClientId}
      apiUrl={openpanelApiUrl}
      trackScreenViews
      trackOutgoingLinks
      trackAttributes
    />
  );
}
