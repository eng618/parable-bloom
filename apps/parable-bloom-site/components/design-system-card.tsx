'use client';

import { Badge } from '@gv-tech/ui-web/badge';
import { Button } from '@gv-tech/ui-web/button';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@gv-tech/ui-web/card';
import Link from 'next/link';

import { trackCtaClick } from '@/lib/analytics';
import { cn } from '@/lib/utils';

type DesignSystemCardProps = {
  title: string;
  body: string;
  marker: string;
  href?: string;
  ctaLabel?: string;
  badge?: string;
};

const badgeStyleMap: Record<string, string> = {
  Available: 'border-brand/20 bg-brand/10 text-brand text-xs',
  default: 'border-brand/15 bg-surface-alt text-text-secondary text-xs',
};

export default function DesignSystemCard({
  title,
  body,
  marker,
  href,
  ctaLabel = 'Open',
  badge,
}: DesignSystemCardProps) {
  return (
    <Card
      className={cn(
        'group border-brand/15 hover:border-brand/35 hover:shadow-grace bg-surface/90 flex h-full flex-col overflow-hidden backdrop-blur-sm transition-all duration-300 hover:-translate-y-1',
      )}
    >
      <CardHeader className="pb-2">
        <div className="mb-2 flex items-start justify-between gap-2">
          <span className="font-display text-brand/70 text-xs tracking-[0.12em] uppercase">{marker}</span>
          {badge && (
            <Badge variant="secondary" className={badgeStyleMap[badge] ?? badgeStyleMap.default}>
              {badge}
            </Badge>
          )}
        </div>
        <CardTitle className="font-display text-text-primary text-lg">{title}</CardTitle>
      </CardHeader>

      <CardContent className="flex-1 pb-4">
        <CardDescription className="text-text-secondary text-sm leading-relaxed">{body}</CardDescription>
      </CardContent>

      <CardFooter className="!border-brand/10 mt-auto !gap-0 !border-t !bg-transparent !p-0">
        <div className="w-full px-6 pt-8 pb-6">
          {href ? (
            <Button
              asChild
              className="bg-brand hover:bg-brand/90 h-11 w-full rounded-[1.125rem] !text-[#fffbf3] transition-all duration-300 hover:!text-[#fffbf3] hover:shadow-md"
              onClick={() => trackCtaClick(title, 'platform_grid', badge)}
            >
              <Link
                href={href}
                target="_blank"
                rel="noopener noreferrer"
                className="!text-[#fffbf3] hover:!text-[#fffbf3]"
              >
                {ctaLabel}
              </Link>
            </Button>
          ) : (
            <Button disabled className="bg-brand/35 h-11 w-full rounded-[1.125rem] !text-[#fffbf3] opacity-70">
              {ctaLabel}
            </Button>
          )}
        </div>
      </CardFooter>
    </Card>
  );
}
