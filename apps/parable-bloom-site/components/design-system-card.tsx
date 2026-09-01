'use client';

import { trackCtaClick } from '@/lib/analytics';
import { cn } from '@/lib/utils';
import { Badge } from '@gv-tech/ui-web/badge';
import { Button } from '@gv-tech/ui-web/button';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@gv-tech/ui-web/card';
import Link from 'next/link';

type DesignSystemCardProps = {
  title: string;
  body: string;
  marker: string;
  href?: string;
  ctaLabel?: string;
  badge?: string;
  animationDelay?: number;
};

const badgeStyleMap: Record<string, string> = {
  Available: 'border-brand/20 bg-brand/10 text-brand text-xs dark:bg-brand/20',
  default: 'border-border bg-muted/60 text-muted-foreground text-xs',
};

export default function DesignSystemCard({
  title,
  body,
  marker,
  href,
  ctaLabel = 'Open',
  badge,
  animationDelay = 0,
}: DesignSystemCardProps) {
  return (
    <Card
      className={cn(
        'animate-fade-in-up group border-border/60 hover:border-brand/40 hover:shadow-grace bg-card/85 dark:bg-card/75 hover:bg-card/95 dark:hover:bg-card/90 flex flex-col overflow-hidden shadow-sm backdrop-blur-sm transition-all duration-300 hover:-translate-y-1',
      )}
      style={{ animationDelay: `${animationDelay}ms` }}
    >
      <CardHeader className="pb-2">
        <div className="mb-2 flex items-start justify-between gap-2">
          <span className="text-3xl transition-transform duration-300 group-hover:scale-110">{marker}</span>
          {badge && (
            <Badge variant="secondary" className={badgeStyleMap[badge] ?? badgeStyleMap.default}>
              {badge}
            </Badge>
          )}
        </div>
        <CardTitle className="font-display text-foreground text-lg">{title}</CardTitle>
      </CardHeader>

      <CardContent className="flex-1 pb-4">
        <CardDescription className="text-muted-foreground text-sm leading-relaxed">{body}</CardDescription>
      </CardContent>

      <CardFooter className="pt-0">
        {href ? (
          <Button
            asChild
            className="bg-brand hover:bg-brand/90 w-full rounded-full text-white transition-all duration-300 hover:shadow-md"
            onClick={() => trackCtaClick(title, 'platform_grid', badge)}
          >
            <Link href={href} target="_blank" rel="noopener noreferrer">
              {ctaLabel}
            </Link>
          </Button>
        ) : (
          <Button variant="outline" disabled className="border-border w-full rounded-full opacity-60">
            {ctaLabel}
          </Button>
        )}
      </CardFooter>
    </Card>
  );
}
