'use client';

import { OpenPanelComponent } from '@openpanel/nextjs';
import { useSyncExternalStore } from 'react';

const openpanelClientId = process.env.NEXT_PUBLIC_OPENPANEL_CLIENT_ID ?? 'b4586d53-64e1-483a-b28b-e19916b29c9b';
const openpanelApiUrl = process.env.NEXT_PUBLIC_OPENPANEL_API_URL ?? 'https://openpanel.gventureshq.com/api';

function subscribe() {
  return () => {};
}

function getSnapshot() {
  if (typeof window === 'undefined') {
    return false;
  }

  if (window.location.hostname === 'localhost') {
    return false;
  }

  if (!openpanelClientId) {
    return false;
  }

  return window.localStorage.getItem('openpanel_ignore') !== 'true';
}

function getServerSnapshot() {
  return false;
}

export default function OpenpanelProvider() {
  const isEnabled = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);

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
