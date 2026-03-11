'use client';

import { SupportFab, Text, cn } from '@gv-tech/ui-web';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import type { ReactNode } from 'react';

const navItems = [
  { href: '/', label: 'Home' },
  { href: '/about', label: 'About' },
  { href: '/privacy', label: 'Privacy' },
  { href: '/terms', label: 'Terms' },
  { href: '/delete-account', label: 'Delete Account' },
];

type SiteShellProps = {
  children: ReactNode;
};

function NavLink({ href, label }: { href: string; label: string }) {
  const pathname = usePathname();
  const isActive = pathname === href;

  return (
    <Link
      href={href}
      className={cn(
        'rounded-full px-3 py-1.5 text-sm font-semibold transition-all duration-300',
        isActive ? 'bg-brand/10 text-brand' : 'text-text-secondary hover:bg-brand-pale hover:text-brand',
      )}
    >
      {label}
    </Link>
  );
}

export default function SiteShell({ children }: SiteShellProps) {
  return (
    <div className="grid min-h-screen grid-rows-[auto_1fr_auto]">
      {/* ── Navigation ── */}
      <header
        className="border-border/40 bg-bg-top/80 sticky top-0 z-40 border-b backdrop-blur-md transition-all duration-300"
        aria-label="Main navigation"
      >
        <div className="mx-auto flex w-full max-w-5xl items-center justify-between gap-4 px-4 py-3 sm:px-6">
          <Link
            href="/"
            aria-label="Parable Bloom home"
            className="flex shrink-0 items-center gap-2 transition-opacity duration-300 hover:opacity-80"
          >
            <span className="text-2xl">🌿</span>
            <Text variant="h3" as="strong" className="font-display text-brand whitespace-nowrap">
              Parable Bloom
            </Text>
          </Link>

          <nav className="flex flex-wrap items-center gap-1" aria-label="Site navigation">
            {navItems.map((item) => (
              <NavLink key={item.href} href={item.href} label={item.label} />
            ))}
          </nav>
        </div>
      </header>

      {/* ── Main content ── */}
      <main className="mx-auto w-full max-w-5xl px-4 py-6 sm:px-6">{children}</main>

      {/* ── Footer ── */}
      <footer className="bg-brand/80 border-t border-white/20 py-8 text-center backdrop-blur-sm">
        <Text variant="caption" className="text-white/80">
          © {new Date().getFullYear()} GVTech. All rights reserved.
        </Text>
        <div className="mt-2 flex justify-center gap-4 text-xs text-white/60">
          <Link href="/privacy" className="transition-colors hover:text-white">
            Privacy Policy
          </Link>
          <span>·</span>
          <Link href="/terms" className="transition-colors hover:text-white">
            Terms of Service
          </Link>
        </div>
      </footer>

      {/* ── Support FAB ── */}
      <SupportFab
        creatorId="eng618"
        title="Support Parable Bloom"
        description="If you enjoy the game, consider buying us a coffee to support continued development 🌿"
        iframeTitle="Support Parable Bloom on Buy Me a Coffee"
      />
    </div>
  );
}
