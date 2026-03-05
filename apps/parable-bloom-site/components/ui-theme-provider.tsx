"use client";

import { ThemeProvider } from "@gv-tech/ui-web";
import type { ReactNode } from "react";

type UiThemeProviderProps = {
  children: ReactNode;
};

export default function UiThemeProvider({ children }: UiThemeProviderProps) {
  return (
    <ThemeProvider
      attribute="class"
      defaultTheme="light"
      enableSystem={false}
      theme={{
        colors: {
          background: "hsl(40 100% 97%)", // floralWhite
          foreground: "hsl(222 47% 11%)", // gray600
          primary: "hsl(151 66% 27%)", // brand green
          primaryForeground: "hsl(0 0% 100%)", // white
          secondary: "hsl(0 0% 96%)", // gray50
          secondaryForeground: "hsl(222 47% 11%)", // gray600
          muted: "hsl(0 0% 92%)", // gray100
          mutedForeground: "hsl(215 16% 47%)", // gray500
          accent: "hsl(0 0% 89%)", // gray200
          accentForeground: "hsl(222 47% 11%)", // gray600
          destructive: "hsl(0 84.2% 60.2%)", // semantic destructive
          destructiveForeground: "hsl(0 0% 100%)", // white
          border: "hsl(0 0% 88%)", // gray300
          input: "hsl(0 0% 88%)", // gray300
          ring: "hsl(151 66% 27%)", // brand green
          card: "hsl(0 0% 100%)", // white
          cardForeground: "hsl(222 47% 11%)", // gray600
          popover: "hsl(0 0% 100%)", // white
          popoverForeground: "hsl(222 47% 11%)", // gray600
          // Custom Parable Bloom colors
          brand: "hsl(151 66% 27%)", // green
          brandSoft: "hsl(93 28% 54%)", // success
        },
        borderRadius: "8px", // lg
      }}
    >
      {children}
    </ThemeProvider>
  );
}
