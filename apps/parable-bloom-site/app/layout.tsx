import type { Metadata, Viewport } from 'next';
import type { ReactNode } from 'react';

import OpenpanelProvider from '@/components/openpanel-provider';
import SiteShell from '@/components/site-shell';
import UiThemeProvider from '@/components/ui-theme-provider';
import { shareImageAlt, siteDescription, siteName, siteUrl } from '@/lib/site';

import './globals.css';

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: siteName,
    template: `%s | ${siteName}`,
  },
  description: siteDescription,
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
    siteName,
    images: [
      {
        url: '/og-image.jpg',
        width: 1200,
        height: 630,
        alt: shareImageAlt,
        type: 'image/jpeg',
      },
      {
        url: '/og-image.png',
        width: 1200,
        height: 1200,
        alt: shareImageAlt,
        type: 'image/png',
      },
    ],
    locale: 'en_US',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    images: [
      {
        url: '/og-image.jpg',
        width: 1200,
        height: 630,
        alt: shareImageAlt,
      },
    ],
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#F9F3E5' },
    { media: '(prefers-color-scheme: dark)', color: '#141914' },
  ],
  width: 'device-width',
  initialScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <UiThemeProvider>
          <SiteShell>{children}</SiteShell>
          <OpenpanelProvider />
        </UiThemeProvider>
      </body>
    </html>
  );
}
