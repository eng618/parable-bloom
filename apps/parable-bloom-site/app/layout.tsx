import type { Metadata, Viewport } from 'next';
import type { ReactNode } from 'react';

import OpenpanelProvider from '@/components/openpanel-provider';
import SiteShell from '@/components/site-shell';
import UiThemeProvider from '@/components/ui-theme-provider';

import './globals.css';

export const metadata: Metadata = {
  metadataBase: new URL('https://parable-bloom.pages.dev'),
  title: {
    default: 'Parable Bloom',
    template: '%s | Parable Bloom',
  },
  description:
    'A calm Christ-centered arrow puzzle. Clear 500+ garden levels by sliding vines, then meet Scripture and reflection along the way.',
  keywords: [
    'puzzle game',
    'christ-centered',
    'faith',
    'scripture',
    'NET Bible',
    'mobile game',
    'parable bloom',
    'garden puzzle',
  ],
  icons: {
    icon: [
      { url: '/favicon.ico' },
      { url: '/favicon-32x32.png', sizes: '32x32', type: 'image/png' },
      { url: '/favicon-16x16.png', sizes: '16x16', type: 'image/png' },
    ],
    apple: [{ url: '/apple-touch-icon.png', sizes: '180x180' }],
  },
  openGraph: {
    title: 'Parable Bloom',
    description:
      'A calm Christ-centered arrow puzzle. Clear 500+ garden levels by sliding vines, then meet Scripture and reflection along the way.',
    url: 'https://parable-bloom.pages.dev',
    siteName: 'Parable Bloom',
    images: [
      {
        url: '/og-image.jpg',
        width: 1200,
        height: 630,
        alt: 'Parable Bloom — gospel through garden puzzles',
      },
    ],
    locale: 'en_US',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Parable Bloom',
    description:
      'A calm Christ-centered arrow puzzle. Clear 500+ garden levels by sliding vines, then meet Scripture and reflection along the way.',
    images: ['/og-image.jpg'],
  },
};

export const viewport: Viewport = {
  themeColor: '#344D2F',
  width: 'device-width',
  initialScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: ReactNode;
}>) {
  return (
    <html lang="en" className="light" style={{ colorScheme: 'light' }} suppressHydrationWarning>
      <body>
        <UiThemeProvider>
          <SiteShell>{children}</SiteShell>
          <OpenpanelProvider />
        </UiThemeProvider>
      </body>
    </html>
  );
}
