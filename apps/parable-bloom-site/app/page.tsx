import DesignSystemCard from '@/components/design-system-card';
import FeatureCard from '@/components/feature-card';
import HeroActions from '@/components/hero-actions';
import { Badge } from '@gv-tech/ui-web/badge';
import { Button } from '@gv-tech/ui-web/button';
import { Card, CardContent } from '@gv-tech/ui-web/card';
import { Separator } from '@gv-tech/ui-web/separator';
import { Text } from '@gv-tech/ui-web/text';
import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Parable Bloom',
  description: 'A Christ-centered arrow puzzle game of faith, scripture, and prayer.',
};

const platforms = [
  {
    marker: '🌐',
    title: 'Play on Web',
    body: 'Play Parable Bloom instantly in your browser. No download required.',
    href: 'https://parable-bloom.web.app/',
    ctaLabel: 'Play Now',
    badge: 'Available',
  },
  {
    marker: '🤖',
    title: 'Android',
    body: 'Download from Google Play and enjoy the full mobile experience.',
    href: 'https://play.google.com/store/apps/details?id=com.garciaericn.parable_bloom',
    ctaLabel: 'Get on Google Play',
    badge: 'Coming Soon',
  },
  {
    marker: '🍏',
    title: 'iOS',
    body: 'Download on the App Store for iPhone and iPad.',
    href: undefined, // Omit href for coming soon to render disabled button
    ctaLabel: 'Download on App Store',
    badge: 'Coming Soon',
  },
];

const features = [
  {
    icon: '👆',
    title: 'Intuitive Gameplay',
    body: 'Simple tap & swipe controls to guide vines through beautiful garden puzzles.',
  },
  {
    icon: '🌸',
    title: 'Beautiful Aesthetics',
    body: 'Lush, organic visuals that evolve as you progress through each garden.',
  },
  {
    icon: '📖',
    title: 'Meaningful Narratives',
    body: 'Unlock faith-inspired stories and parables as you complete each level.',
  },
  {
    icon: '✈️',
    title: 'Offline Play',
    body: 'Enjoy the serenity anywhere, anytime — no internet connection required.',
  },
];

export default function HomePage() {
  return (
    <div className="flex flex-col gap-8 pb-10">
      {/* ── Hero ── */}
      <section className="animate-fade-in-up border-border/60 shadow-grace from-card/95 to-muted/60 dark:from-card/85 dark:to-muted/30 relative overflow-hidden rounded-3xl border bg-gradient-to-br px-6 py-10 backdrop-blur-sm sm:px-10 sm:py-14">
        {/* Decorative ambient blobs */}
        <div className="bg-brand-soft/15 dark:bg-brand-soft/10 pointer-events-none absolute -top-16 -right-16 h-64 w-64 rounded-full blur-3xl" />
        <div className="bg-brand/10 dark:bg-brand/15 pointer-events-none absolute -bottom-12 -left-12 h-48 w-48 rounded-full blur-2xl" />

        <div className="relative">
          <div className="mb-4 flex flex-wrap items-center gap-3">
            <span className="animate-float text-4xl sm:text-6xl">🌿</span>
            <Badge
              variant="secondary"
              className="bg-brand/10 text-brand border-brand/20 dark:bg-brand/20 text-xs sm:text-sm"
            >
              Christ-Centered Puzzler
            </Badge>
          </div>

          <h1 className="font-display text-foreground mb-4 text-3xl leading-tight font-bold tracking-tight sm:text-5xl lg:text-6xl">
            Parable Bloom
          </h1>

          <Text variant="body" className="text-muted-foreground mb-6 max-w-2xl text-base leading-relaxed sm:text-lg">
            A journey of prayerful reflection, puzzles, and faith. Guide vines through gardens of grace and uncover the
            parables of Jesus.
          </Text>

          <HeroActions />
        </div>
      </section>

      {/* ── Platform cards ── */}
      <section aria-label="Platform availability">
        <Text variant="h2" className="font-display text-foreground mb-4 text-xl font-semibold sm:text-2xl">
          Where to Play
        </Text>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {platforms.map((platform, i) => (
            <DesignSystemCard
              key={platform.title}
              marker={platform.marker}
              title={platform.title}
              body={platform.body}
              href={platform.href}
              ctaLabel={platform.ctaLabel}
              badge={platform.badge}
              animationDelay={i * 100}
            />
          ))}
        </div>
      </section>

      <Separator className="opacity-40" />

      {/* ── Features ── */}
      <section aria-label="Game features">
        <Text variant="h2" className="font-display text-foreground mb-2 text-xl font-semibold sm:text-2xl">
          Discover Peace in Puzzles
        </Text>
        <Text variant="body" className="text-muted-foreground mb-6 max-w-2xl">
          Parable Bloom isn&apos;t just a game — it&apos;s a moment of calm in your busy day. Immerse yourself in a
          world where logic meets devotional reflection.
        </Text>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {features.map((feature, i) => (
            <FeatureCard key={feature.title} icon={feature.icon} title={feature.title} body={feature.body} index={i} />
          ))}
        </div>
      </section>

      {/* ── Join the Journey ── */}
      <Card className="animate-fade-in-up border-border/60 hover:border-brand/40 bg-card/80 dark:bg-card/60 overflow-hidden shadow-sm backdrop-blur-sm transition-all duration-300">
        <CardContent className="p-6 text-center sm:p-10">
          <span className="animate-float mb-3 block text-4xl">🙏</span>
          <h2 className="font-display text-foreground mb-2 text-2xl font-semibold sm:text-3xl">Join the Journey</h2>
          <p className="text-muted-foreground mx-auto mb-6 max-w-md text-sm leading-relaxed sm:text-base">
            Follow the development of Parable Bloom and be part of a growing community finding peace through puzzles.
          </p>
          <Button
            asChild
            size="lg"
            className="bg-brand hover:bg-brand/90 rounded-full text-white shadow-md transition-all duration-300 hover:-translate-y-0.5 hover:shadow-lg"
          >
            <Link href="https://github.com/eng618/parable-bloom" target="_blank" rel="noopener noreferrer">
              ⭐ Star on GitHub
            </Link>
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
