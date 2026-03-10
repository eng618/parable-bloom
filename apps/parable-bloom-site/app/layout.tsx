import PlausibleProvider from '@/components/plausible-provider';
import SiteShell from '@/components/site-shell';
import UiThemeProvider from '@/components/ui-theme-provider';
import type { Metadata, Viewport } from 'next';
import type { ReactNode } from 'react';
import './globals.css';

export const metadata: Metadata = {
  title: {
    default: 'Parable Bloom',
    template: '%s | Parable Bloom',
  },
  description: 'A zen hyper-casual arrow puzzle game with faith-based themes.',
  keywords: ['puzzle game', 'zen', 'faith', 'mobile game', 'parable bloom'],
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
