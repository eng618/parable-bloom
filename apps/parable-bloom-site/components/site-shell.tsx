'use client';

import { trackNavigationClick } from '@/lib/analytics';
import { cn } from '@/lib/utils';
import { Button } from '@gv-tech/ui-web/button';
import { ScrollToTop } from '@gv-tech/ui-web/scroll-to-top';
import {
  Sheet,
  SheetClose,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from '@gv-tech/ui-web/sheet';
import { SupportFab } from '@gv-tech/ui-web/support-fab';
import { Text } from '@gv-tech/ui-web/text';
import { ThemeToggle } from '@gv-tech/ui-web/theme-toggle';
import { Menu } from 'lucide-react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState, type ReactNode } from 'react';

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
      onClick={() => trackNavigationClick(href, 'header', label)}
      className={cn(
        'rounded-full px-3 py-1.5 text-sm font-semibold transition-all duration-300',
        isActive
          ? 'bg-brand/10 text-brand dark:bg-brand/20 font-bold'
          : 'text-text-secondary hover:bg-brand-pale hover:text-brand',
      )}
    >
      {label}
    </Link>
  );
}

export default function SiteShell({ children }: SiteShellProps) {
  const pathname = usePathname();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  return (
    <div className="grid min-h-screen grid-rows-[auto_1fr_auto]">
      {/* ── Header ── */}
      <header
        className="border-border/40 bg-background/80 sticky top-0 z-40 border-b backdrop-blur-md transition-all duration-300"
        aria-label="Main navigation"
      >
        <div className="mx-auto flex w-full max-w-5xl items-center justify-between gap-4 px-4 py-3 sm:px-6">
          <Link
            href="/"
            aria-label="Parable Bloom home"
            onClick={() => trackNavigationClick('/', 'header', 'Logo')}
            className="flex shrink-0 items-center gap-2.5 transition-opacity duration-300 hover:opacity-85"
          >
            <span className="text-2xl">🌿</span>
            <Text variant="h3" as="strong" className="font-display text-brand whitespace-nowrap">
              Parable Bloom
            </Text>
          </Link>

          {/* Desktop Navigation */}
          <div className="hidden md:flex md:items-center md:gap-3">
            <nav className="flex items-center gap-1" aria-label="Desktop site navigation">
              {navItems.map((item) => (
                <NavLink key={item.href} href={item.href} label={item.label} />
              ))}
            </nav>
            <div className="bg-border/60 h-4 w-px" />
            {mounted ? <ThemeToggle variant="ternary" /> : <div className="h-9 w-9" aria-hidden="true" />}
          </div>

          {/* Mobile Controls & Drawer */}
          <div className="flex items-center gap-2 md:hidden">
            {mounted ? <ThemeToggle variant="ternary" /> : <div className="h-9 w-9" aria-hidden="true" />}
            <Sheet>
              <SheetTrigger asChild>
                <Button variant="ghost" size="icon" aria-label="Open navigation menu">
                  <Menu className="h-5 w-5" />
                </Button>
              </SheetTrigger>
              <SheetContent side="right" className="flex w-[280px] flex-col gap-6 p-6 sm:w-[320px]">
                <SheetHeader className="p-0 text-left">
                  <SheetTitle className="font-display text-brand flex items-center gap-2 text-lg">
                    <span>🌿</span> Parable Bloom
                  </SheetTitle>
                  <SheetDescription className="sr-only">Mobile navigation menu for Parable Bloom</SheetDescription>
                </SheetHeader>
                <nav className="flex flex-col gap-2" aria-label="Mobile site navigation">
                  {navItems.map((item) => (
                    <SheetClose asChild key={item.href}>
                      <Link
                        href={item.href}
                        onClick={() => trackNavigationClick(item.href, 'mobile_drawer', item.label)}
                        className={cn(
                          'rounded-xl px-4 py-2.5 text-base font-semibold transition-all duration-200',
                          pathname === item.href
                            ? 'bg-brand/10 text-brand dark:bg-brand/20 font-bold'
                            : 'text-text-secondary hover:bg-brand-pale hover:text-brand',
                        )}
                      >
                        {item.label}
                      </Link>
                    </SheetClose>
                  ))}
                </nav>
                <div className="border-border/60 mt-auto flex flex-col gap-2.5 border-t pt-4">
                  <SheetClose asChild>
                    <Button asChild className="bg-brand hover:bg-brand/90 w-full rounded-full text-white" size="sm">
                      <Link href="https://parable-bloom.web.app/" target="_blank" rel="noopener noreferrer">
                        🌐 Play on Web
                      </Link>
                    </Button>
                  </SheetClose>
                </div>
              </SheetContent>
            </Sheet>
          </div>
        </div>
      </header>

      {/* ── Main content ── */}
      <main className="mx-auto w-full max-w-5xl px-4 py-6 sm:px-6">{children}</main>

      {/* ── Footer ── */}
      <footer className="border-border/50 bg-surface-alt/60 dark:bg-card/40 border-t py-8 text-center backdrop-blur-sm transition-colors duration-300">
        <div className="mx-auto max-w-5xl px-4 sm:px-6">
          <Text variant="caption" className="text-muted-foreground block">
            © {new Date().getFullYear()} GVTech. All rights reserved.
          </Text>
          <div className="text-muted-foreground mt-3 flex flex-wrap justify-center gap-4 text-xs">
            <Link
              href="/about"
              onClick={() => trackNavigationClick('/about', 'footer', 'About')}
              className="hover:text-foreground transition-colors"
            >
              About
            </Link>
            <span>·</span>
            <Link
              href="/privacy"
              onClick={() => trackNavigationClick('/privacy', 'footer', 'Privacy Policy')}
              className="hover:text-foreground transition-colors"
            >
              Privacy Policy
            </Link>
            <span>·</span>
            <Link
              href="/terms"
              onClick={() => trackNavigationClick('/terms', 'footer', 'Terms of Service')}
              className="hover:text-foreground transition-colors"
            >
              Terms of Service
            </Link>
            <span>·</span>
            <Link
              href="/delete-account"
              onClick={() => trackNavigationClick('/delete-account', 'footer', 'Delete Account')}
              className="hover:text-foreground transition-colors"
            >
              Delete Account
            </Link>
          </div>
        </div>
      </footer>

      {/* ── Floating Controls ── */}
      <ScrollToTop className="!right-6 !bottom-20 !z-40" />
      <SupportFab
        creatorId="eng618"
        title="Support Parable Bloom"
        description="If you enjoy the game, consider buying us a coffee to support continued development 🌿"
        iframeTitle="Support Parable Bloom on Buy Me a Coffee"
      />
    </div>
  );
}
