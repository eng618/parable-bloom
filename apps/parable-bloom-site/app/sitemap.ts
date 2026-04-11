import type { MetadataRoute } from 'next';

const siteUrl = 'https://parable-bloom.pages.dev';

export const dynamic = 'force-static';

const routes = [
  {
    path: '/',
    lastModified: '2026-01-11',
  },
  {
    path: '/about',
    lastModified: '2026-01-11',
  },
  {
    path: '/privacy',
    lastModified: '2026-02-04',
  },
  {
    path: '/terms',
    lastModified: '2026-02-04',
  },
] as const;

export default function sitemap(): MetadataRoute.Sitemap {
  return routes.map(({ path, lastModified }) => ({
    url: `${siteUrl}${path}`,
    lastModified,
    changeFrequency: 'daily',
    priority: 0.5,
  }));
}
