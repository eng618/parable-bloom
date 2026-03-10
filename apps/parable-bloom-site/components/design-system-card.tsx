'use client';

import {
  Badge,
  Button,
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
  cn,
} from '@gv-tech/ui-web';
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
  Available: 'border-brand/20 bg-brand/10 text-brand text-xs',
  default: 'border-border bg-surface-alt text-text-secondary text-xs',
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
        'animate-fade-in-up group border-border/60 hover:border-brand/30 hover:shadow-zen flex flex-col overflow-hidden bg-white/80 backdrop-blur-sm transition-all duration-300 hover:-translate-y-1 hover:bg-white/95',
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
        <CardTitle className="font-display text-text-primary text-lg">{title}</CardTitle>
      </CardHeader>

      <CardContent className="flex-1 pb-4">
        <CardDescription className="text-text-secondary text-sm leading-relaxed">{body}</CardDescription>
      </CardContent>

      <CardFooter className="pt-0">
        {href ? (
          <Button
            asChild
            className="bg-brand hover:bg-brand/90 w-full rounded-full transition-all duration-300 hover:shadow-md"
          >
            <Link href={href} target="_blank" rel="noopener noreferrer">
              {ctaLabel}
            </Link>
          </Button>
        ) : (
          <Button disabled className="w-full rounded-full opacity-60">
            {ctaLabel}
          </Button>
        )}
      </CardFooter>
    </Card>
  );
}
