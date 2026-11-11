'use client';

import { ThemeToggle } from '@gv-tech/ui-web/theme-toggle';
import { useSyncExternalStore } from 'react';

import { cn } from '@/lib/utils';

const controlClass = 'border-brand/40 bg-surface text-brand hover:bg-brand/10 hover:text-brand size-10 shrink-0 border';

const subscribe = () => () => {};

type ThemeMenuProps = {
  className?: string;
};

export default function ThemeMenu({ className }: ThemeMenuProps) {
  const mounted = useSyncExternalStore(
    subscribe,
    () => true,
    () => false,
  );

  if (!mounted) {
    return <span className={cn('inline-block size-10 shrink-0', className)} aria-hidden="true" />;
  }

  return <ThemeToggle variant="ternary" className={cn(controlClass, className)} />;
}
