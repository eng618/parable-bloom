import Link from "next/link";
import type { ReactNode } from "react";

const navItems = [
  { href: "/", label: "Home" },
  { href: "/about", label: "About" },
  { href: "/privacy", label: "Privacy" },
  { href: "/terms", label: "Terms" },
  { href: "/delete-account", label: "Delete Account" },
];

type SiteShellProps = {
  children: ReactNode;
};

export default function SiteShell({ children }: SiteShellProps) {
  return (
    <div className="site-shell">
      <header className="container site-nav" aria-label="Main navigation">
        <Link href="/" aria-label="Parable Bloom home">
          <strong>Parable Bloom</strong>
        </Link>
        <nav className="site-nav-links">
          {navItems.map((item) => (
            <Link key={item.href} className="site-nav-link" href={item.href}>
              {item.label}
            </Link>
          ))}
        </nav>
      </header>
      <main className="container">{children}</main>
      <footer className="footer">(c) {new Date().getFullYear()} GVTech. All rights reserved.</footer>
    </div>
  );
}
