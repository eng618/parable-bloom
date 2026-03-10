import PlausibleAnalytics from '@/components/plausible-analytics';
import SiteShell from '@/components/site-shell';
import UiThemeProvider from '@/components/ui-theme-provider';
import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import './globals.css';

export const metadata: Metadata = {
  title: 'Parable Bloom',
  description: 'A zen hyper-casual arrow puzzle game with faith-based themes.',
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
          <PlausibleAnalytics />
        </UiThemeProvider>
      </body>
    </html>
  );
}
