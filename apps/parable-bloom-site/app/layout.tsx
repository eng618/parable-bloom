import PlausibleProvider from '@/components/plausible-provider';
import SiteShell from '@/components/site-shell';
import UiThemeProvider from '@/components/ui-theme-provider';
import type { Metadata, Viewport } from 'next';
import type { ReactNode } from 'react';
import './globals.css';

export const metadata: Metadata = {
  metadataBase: new URL('https://parable-bloom.pages.dev'),
  title: {
    default: 'Parable Bloom',
    template: '%s | Parable Bloom',
  },
  description: 'A zen hyper-casual arrow puzzle game with faith-based themes.',
  keywords: ['puzzle game', 'zen', 'faith', 'mobile game', 'parable bloom'],
  icons: {
    icon: [
      { url: '/favicon.ico' },
      { url: '/favicon-32x32.png', sizes: '32x32', type: 'image/png' },
      { url: '/favicon-16x16.png', sizes: '16x16', type: 'image/png' },
    ],
    apple: [{ url: '/apple-touch-icon.png', sizes: '180x180' }],
  },
};

export const viewport: Viewport = {
  themeColor: '#177245',
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
          <PlausibleProvider />
        </UiThemeProvider>
      </body>
    </html>
  );
}
