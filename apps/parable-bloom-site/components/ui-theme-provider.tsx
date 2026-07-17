'use client';

import { ThemeProvider } from '@gv-tech/ui-web/theme-provider';
import type { ReactNode } from 'react';

type UiThemeProviderProps = {
  children: ReactNode;
};

export default function UiThemeProvider({ children }: UiThemeProviderProps) {
  return (
    <ThemeProvider attribute="class" defaultTheme="light" enableSystem={false}>
      {children}
    </ThemeProvider>
  );
}
