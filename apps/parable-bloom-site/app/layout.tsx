import type { Metadata } from "next";
import type { ReactNode } from "react";
import "./globals.css";
import SiteShell from "@/components/site-shell";
import UiThemeProvider from "@/components/ui-theme-provider";

export const metadata: Metadata = {
  title: "Parable Bloom",
  description: "A zen hyper-casual arrow puzzle game with faith-based themes.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: ReactNode;
}>) {
  return (
    <html lang="en" className="light" style={{ colorScheme: "light" }} suppressHydrationWarning>
      <body>
        <UiThemeProvider>
          <SiteShell>{children}</SiteShell>
        </UiThemeProvider>
      </body>
    </html>
  );
}
