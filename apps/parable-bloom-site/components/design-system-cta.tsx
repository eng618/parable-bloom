'use client';

import { Button } from "@gv-tech/ui-web";
import Link from "next/link";
import type { ReactNode } from "react";

type DesignSystemCtaProps = {
  href: string;
  variant?: "primary" | "secondary";
  children: ReactNode;
};

export default function DesignSystemCta({ href, variant = "primary", children }: DesignSystemCtaProps) {
  return (
    <Button asChild className={`cta ${variant === "primary" ? "cta-primary" : "cta-secondary"}`}>
      <Link href={href}>{children}</Link>
    </Button>
  );
}
