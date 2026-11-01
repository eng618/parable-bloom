'use client';

import { SupportFab } from '@gv-tech/ui-web/support-fab';
import { Text } from '@gv-tech/ui-web/text';
import Image from 'next/image';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import type { ReactNode } from 'react';

import { trackNavigationClick } from '@/lib/analytics';
import { cn } from '@/lib/utils';

const currentYear = new Date().getFullYear();

const navItems = [
  { href: '/', label: 'Home' },
  { href: '/about', label: 'About' },
  { href: '/attributions', label: 'Attributions' },
  { href: '/support', label: 'Support' },
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
      onClick={() => trackNavigationClick(href, 'header', label)}
      className={cn(
        'rounded-xl px-3 py-1.5 text-sm font-semibold transition-all duration-300',
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
      <header
        className="border-brand/10 bg-bg-top/85 sticky top-0 z-40 border-b backdrop-blur-md transition-all duration-300"
        aria-label="Main navigation"
      >
        <div className="mx-auto flex w-full max-w-6xl items-center justify-between gap-4 px-4 py-3 sm:px-6">
          <Link
            href="/"
            aria-label="Parable Bloom home"
            onClick={() => trackNavigationClick('/', 'header', 'Logo')}
            className="flex shrink-0 items-center gap-2.5 transition-opacity duration-300 hover:opacity-80"
          >
            <Image src="/art/leaf_sprig.webp" alt="" width={28} height={18} className="opacity-90" aria-hidden="true" />
            <Text variant="h3" as="strong" className="font-display text-brand whitespace-nowrap text-lg sm:text-xl">
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

      <main className="mx-auto w-full max-w-6xl px-4 py-6 sm:px-6">{children}</main>

      <footer className="bg-brand border-t border-brand/20 py-10 text-center">
        <Text variant="caption" className="text-surface/85 font-display text-sm tracking-wide">
          © {currentYear} GVTech. All rights reserved.
        </Text>
        <div className="text-surface/65 mt-3 flex flex-wrap justify-center gap-x-4 gap-y-2 text-xs">
          <Link
            href="/privacy"
            onClick={() => trackNavigationClick('/privacy', 'footer', 'Privacy Policy')}
            className="hover:text-surface transition-colors"
          >
            Privacy Policy
          </Link>
          <span aria-hidden="true">·</span>
          <Link
            href="/attributions"
            onClick={() => trackNavigationClick('/attributions', 'footer', 'Attributions')}
            className="hover:text-surface transition-colors"
          >
            Attributions
          </Link>
          <span aria-hidden="true">·</span>
          <Link
            href="/support"
            onClick={() => trackNavigationClick('/support', 'footer', 'Support')}
            className="hover:text-surface transition-colors"
          >
            Support
          </Link>
          <span aria-hidden="true">·</span>
          <Link
            href="/terms"
            onClick={() => trackNavigationClick('/terms', 'footer', 'Terms of Service')}
            className="hover:text-surface transition-colors"
          >
            Terms of Service
          </Link>
        </div>
      </footer>

      <SupportFab
        creatorId="eng618"
        title="Support Parable Bloom"
        description="If you enjoy the garden, consider buying us a coffee to support continued development."
        iframeTitle="Support Parable Bloom on Buy Me a Coffee"
      />
    </div>
  );
}
