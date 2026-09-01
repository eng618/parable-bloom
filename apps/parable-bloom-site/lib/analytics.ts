'use client';

export function isAnalyticsAllowed(): boolean {
  if (typeof window === 'undefined') {
    return false;
  }
  if (window.location.hostname === 'localhost') {
    return false;
  }
  return !(
    window.localStorage.getItem('openpanel_ignore') === 'true' ||
    window.localStorage.getItem('plausible_ignore') === 'true'
  );
}

export function trackEvent(name: string, properties?: Record<string, unknown>): void {
  if (!isAnalyticsAllowed()) {
    return;
  }

  try {
    const windowWithOp = window as unknown as {
      op?: {
        track: (eventName: string, props?: Record<string, unknown>) => void;
      };
    };

    if (windowWithOp.op && typeof windowWithOp.op.track === 'function') {
      windowWithOp.op.track(name, properties);
    }
  } catch (err) {
    // Non-blocking telemetry error
    console.debug('Telemetry track failed', err);
  }
}

export function trackCtaClick(ctaName: string, location: string, badgeStatus?: string): void {
  trackEvent('cta_clicked', {
    cta_name: ctaName,
    location,
    ...(badgeStatus ? { badge_status: badgeStatus } : {}),
  });
}

export function trackNavigationClick(
  destination: string,
  location: 'header' | 'footer' | 'mobile_drawer',
  label: string,
): void {
  trackEvent('navigation_clicked', {
    destination,
    location,
    label,
  });
}

export function trackFeatureExplored(featureTitle: string, featureIndex: number): void {
  trackEvent('feature_explored', {
    feature_title: featureTitle,
    feature_index: featureIndex,
  });
}

export function trackThemeToggle(theme: string): void {
  trackEvent('theme_toggled', {
    theme,
  });
}
