'use client';

import { OpenPanelComponent } from '@openpanel/nextjs';
import { useEffect, useState } from 'react';

const openpanelClientId = process.env.NEXT_PUBLIC_OPENPANEL_CLIENT_ID ?? 'b4586d53-64e1-483a-b28b-e19916b29c9b';
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

    const isOptedOut = window.localStorage.getItem('openpanel_ignore') === 'true';

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
