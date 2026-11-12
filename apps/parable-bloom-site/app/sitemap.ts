import type { MetadataRoute } from 'next';

import { siteUrl } from '@/lib/site';

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
    path: '/attributions',
    lastModified: '2026-11-12',
  },
  {
    path: '/support',
    lastModified: '2026-09-04',
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
