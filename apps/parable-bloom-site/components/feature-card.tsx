'use client';

import { trackFeatureExplored } from '@/lib/analytics';

type FeatureCardProps = {
  icon: string;
  title: string;
  body: string;
  index: number;
};

export default function FeatureCard({ icon, title, body, index }: FeatureCardProps) {
  return (
    <div
      className="animate-fade-in-up group border-border/50 hover:border-brand/30 hover:shadow-grace flex cursor-default gap-4 rounded-2xl border bg-white/80 p-5 backdrop-blur-sm transition-all duration-300 hover:-translate-y-0.5 hover:bg-white/95"
      style={{ animationDelay: `${index * 80}ms` }}
      onMouseEnter={() => trackFeatureExplored(title, index)}
    >
      <span className="bg-brand/8 mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-xl text-xl transition-transform duration-300 group-hover:scale-110">
        {icon}
      </span>
      <div>
        <h3 className="font-display text-text-primary mb-1 font-semibold">{title}</h3>
        <p className="text-text-secondary text-sm leading-relaxed">{body}</p>
      </div>
    </div>
  );
}
