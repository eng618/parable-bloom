'use client';

import { Button } from '@gv-tech/ui-web/button';
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from '@gv-tech/ui-web/sheet';
import { SupportFab } from '@gv-tech/ui-web/support-fab';
import { Text } from '@gv-tech/ui-web/text';
import { MenuIcon } from 'lucide-react';
import Image from 'next/image';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState, type ReactNode } from 'react';

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

function NavLink({
  href,
  label,
  onNavigate,
  className,
}: {
  href: string;
  label: string;
  onNavigate?: () => void;
  className?: string;
}) {
  const pathname = usePathname();
  const isActive = pathname === href;

  return (
    <Link
      href={href}
      onClick={() => {
        trackNavigationClick(href, 'header', label);
        onNavigate?.();
      }}
      className={cn(
        'rounded-xl px-3 py-1.5 text-sm font-semibold transition-all duration-300',
        isActive ? 'bg-brand/10 text-brand' : 'text-text-secondary hover:bg-brand-pale hover:text-brand',
        className,
      )}
    >
      {label}
    </Link>
  );
}

function BrandMark() {
  return (
    <Link
      href="/"
      aria-label="Parable Bloom home"
      onClick={() => trackNavigationClick('/', 'header', 'Logo')}
      className="flex shrink-0 items-center gap-2.5 transition-opacity duration-300 hover:opacity-80"
    >
      <Image src="/art/leaf_sprig.png" alt="" width={28} height={18} className="opacity-90" aria-hidden="true" />
      <Text variant="h3" as="strong" className="font-display text-brand whitespace-nowrap text-lg sm:text-xl">
        Parable Bloom
      </Text>
    </Link>
  );
}

export default function SiteShell({ children }: SiteShellProps) {
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <div className="grid min-h-screen grid-rows-[auto_1fr_auto]">
      <header
        className="border-brand/10 bg-bg-top/85 sticky top-0 z-40 border-b backdrop-blur-md transition-all duration-300"
        aria-label="Main navigation"
      >
        <div className="mx-auto flex w-full max-w-6xl items-center justify-between gap-3 px-4 py-3 sm:px-6">
          <BrandMark />

          {/* Wide screens: single-row horizontal nav (no wrap / no cutoff) */}
          <nav className="hidden items-center gap-1 lg:flex" aria-label="Site navigation">
            {navItems.map((item) => (
              <NavLink key={item.href} href={item.href} label={item.label} />
            ))}
          </nav>

          {/* Phone + tablet / narrow desktop: hamburger + sheet drawer */}
          <Sheet open={menuOpen} onOpenChange={setMenuOpen}>
            <SheetTrigger asChild>
              <Button
                type="button"
                variant="outline"
                size="icon"
                className="border-brand/40 bg-surface text-brand hover:bg-brand/10 hover:text-brand size-10 shrink-0 lg:hidden"
                aria-label="Open menu"
              >
                <MenuIcon className="size-5" aria-hidden="true" />
              </Button>
            </SheetTrigger>
            <SheetContent
              side="right"
              className="bg-surface border-brand/15 w-[min(100%,20rem)] gap-0 p-0"
            >
              <SheetHeader className="border-brand/10 border-b px-5 py-4 text-left">
                <SheetTitle className="font-display text-brand text-xl">Parable Bloom</SheetTitle>
                <SheetDescription className="text-text-secondary text-sm">
                  Navigate the garden site.
                </SheetDescription>
              </SheetHeader>
              <nav className="flex flex-col gap-1 p-4" aria-label="Mobile site navigation">
                {navItems.map((item) => (
                  <NavLink
                    key={item.href}
                    href={item.href}
                    label={item.label}
                    onNavigate={() => {
                      setMenuOpen(false);
                    }}
                    className="w-full px-4 py-3 text-base"
                  />
                ))}
              </nav>
            </SheetContent>
          </Sheet>
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
