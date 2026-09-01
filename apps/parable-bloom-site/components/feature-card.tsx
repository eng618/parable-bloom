'use client';

import { trackFeatureExplored } from '@/lib/analytics';
import { Card, CardContent } from '@gv-tech/ui-web/card';

type FeatureCardProps = {
  icon: string;
  title: string;
  body: string;
  index: number;
};

export default function FeatureCard({ icon, title, body, index }: FeatureCardProps) {
  return (
    <Card
      className="animate-fade-in-up group border-border/60 hover:border-brand/40 hover:shadow-grace bg-card/85 dark:bg-card/75 hover:bg-card/95 dark:hover:bg-card/90 flex cursor-default overflow-hidden p-5 shadow-sm backdrop-blur-sm transition-all duration-300 hover:-translate-y-0.5"
      style={{ animationDelay: `${index * 80}ms` }}
      onMouseEnter={() => trackFeatureExplored(title, index)}
    >
      <CardContent className="flex items-start gap-4 p-0">
        <span className="bg-brand/10 dark:bg-brand/20 mt-0.5 flex h-11 w-11 shrink-0 items-center justify-center rounded-xl text-2xl transition-transform duration-300 group-hover:scale-110">
          {icon}
        </span>
        <div>
          <h3 className="font-display text-foreground mb-1 text-lg font-semibold">{title}</h3>
          <p className="text-muted-foreground text-sm leading-relaxed">{body}</p>
        </div>
      </CardContent>
    </Card>
  );
}
