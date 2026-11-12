/** Public marketing host. Share tags and the sitemap use this origin. */
export const siteUrl = 'https://parablebloom.gventureshq.com';

export const siteName = 'Parable Bloom';

export const siteDescription =
  'A calm Christ-centered arrow puzzle. Clear 500+ garden levels by sliding vines, then meet Scripture and reflection along the way.';

export const shareImageAlt = 'Parable Bloom — a calm Christ-centered puzzle';

export const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.garciaericn.parable_bloom';

/** Homepage structured data for the marketing host and the Android open test. */
export const siteJsonLd = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'WebSite',
      name: siteName,
      url: siteUrl,
      description: siteDescription,
    },
    {
      '@type': 'SoftwareApplication',
      name: siteName,
      applicationCategory: 'GameApplication',
      operatingSystem: 'Android, Web',
      url: siteUrl,
      image: `${siteUrl}/og-image.jpg`,
      description: siteDescription,
      installUrl: playStoreUrl,
    },
  ],
};
