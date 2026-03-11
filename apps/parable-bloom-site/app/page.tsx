import DesignSystemCard from '@/components/design-system-card';
import { Badge, Separator, Text } from '@gv-tech/ui-web';
import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Parable Bloom',
  description: 'A zen hyper-casual arrow puzzle game with faith-based themes.',
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
    href: 'https://play.google.com/store/apps/details?id=com.eng618.parablebloom',
    ctaLabel: 'Get on Google Play',
    badge: 'Coming Soon',
  },
  {
    marker: '🍏',
    title: 'iOS',
    body: 'Download on the App Store for iPhone and iPad.',
    href: 'https://apps.apple.com/app/parable-bloom/id1234567890',
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
      <section className="animate-fade-in-up border-border/60 to-surface-alt/95 shadow-zen relative overflow-hidden rounded-3xl border bg-gradient-to-br from-white/90 px-6 py-10 sm:px-10 sm:py-14">
        {/* Decorative blobs */}
        <div className="bg-brand-soft/10 pointer-events-none absolute -top-16 -right-16 h-64 w-64 rounded-full blur-3xl" />
        <div className="bg-brand/8 pointer-events-none absolute -bottom-12 -left-12 h-48 w-48 rounded-full blur-2xl" />

        <div className="relative">
          <div className="mb-4 flex items-center gap-3">
            <span className="animate-float text-5xl sm:text-6xl">🌿</span>
            <Badge variant="secondary" className="bg-brand/10 text-brand border-brand/20">
              Zen Puzzle Game
            </Badge>
          </div>

          <h1 className="font-display text-text-primary mb-4 text-4xl leading-tight font-bold tracking-tight sm:text-5xl lg:text-6xl">
            Parable Bloom
          </h1>

          <Text variant="body" className="text-text-secondary mb-6 max-w-2xl text-base sm:text-lg">
            A journey of mindfulness, puzzles, and faith. Guide vines through beautiful gardens and uncover timeless
            parables in this zen puzzler.
          </Text>

          <div className="flex flex-wrap gap-3">
            <Link
              href="https://parable-bloom.web.app/"
              target="_blank"
              rel="noopener noreferrer"
              className="bg-brand hover:bg-brand/90 focus-visible:ring-brand/50 inline-flex items-center gap-2 rounded-full px-6 py-2.5 text-sm font-semibold text-white shadow-md transition-all duration-300 hover:-translate-y-0.5 hover:shadow-lg focus-visible:ring-2 focus-visible:outline-none"
            >
              🌐 Play on Web
            </Link>
            <Link
              href="https://play.google.com/store/apps/details?id=com.eng618.parablebloom"
              target="_blank"
              rel="noopener noreferrer"
              className="border-border text-text-primary hover:border-brand/40 hover:bg-surface-alt inline-flex items-center gap-2 rounded-full border bg-white px-6 py-2.5 text-sm font-semibold transition-all duration-300 hover:-translate-y-0.5 hover:shadow-md"
            >
              🤖 Google Play
            </Link>
            <Link
              href="https://apps.apple.com/app/parable-bloom/id1234567890"
              target="_blank"
              rel="noopener noreferrer"
              className="border-border text-text-primary hover:border-brand/40 hover:bg-surface-alt inline-flex items-center gap-2 rounded-full border bg-white px-6 py-2.5 text-sm font-semibold transition-all duration-300 hover:-translate-y-0.5 hover:shadow-md"
            >
              🍏 App Store
            </Link>
          </div>
        </div>
      </section>

      {/* ── Platform cards ── */}
      <section aria-label="Platform availability">
        <Text variant="h2" className="font-display text-text-primary mb-4 text-xl font-semibold">
          Where to Play
        </Text>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
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
        <Text variant="h2" className="font-display text-text-primary mb-2 text-xl font-semibold">
          Discover Peace in Puzzles
        </Text>
        <Text variant="body" className="text-text-secondary mb-6 max-w-2xl">
          Parable Bloom isn&apos;t just a game — it&apos;s a moment of calm in your busy day. Immerse yourself in a
          world where logic meets spiritual reflection.
        </Text>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {features.map((feature, i) => (
            <div
              key={feature.title}
              className="animate-fade-in-up group border-border/50 hover:border-brand/30 hover:shadow-zen flex gap-4 rounded-2xl border bg-white/80 p-5 backdrop-blur-sm transition-all duration-300 hover:-translate-y-0.5 hover:bg-white/95"
              style={{ animationDelay: `${i * 80}ms` }}
            >
              <span className="bg-brand/8 mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-xl text-xl transition-transform duration-300 group-hover:scale-110">
                {feature.icon}
              </span>
              <div>
                <h3 className="font-display text-text-primary mb-1 font-semibold">{feature.title}</h3>
                <p className="text-text-secondary text-sm leading-relaxed">{feature.body}</p>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* ── Join the Journey ── */}
      <section className="animate-fade-in-up border-brand/20 rounded-2xl border bg-white/60 p-6 text-center backdrop-blur-sm sm:p-8">
        <span className="mb-3 block text-4xl">🙏</span>
        <h2 className="font-display text-text-primary mb-2 text-2xl font-semibold">Join the Journey</h2>
        <p className="text-text-secondary mx-auto mb-5 max-w-md text-sm sm:text-base">
          Follow the development of Parable Bloom and be part of a growing community finding peace through puzzles.
        </p>
        <a
          href="https://github.com/eng618/parable-bloom"
          target="_blank"
          rel="noopener noreferrer"
          className="bg-brand hover:bg-brand/90 inline-flex items-center gap-2 rounded-full px-6 py-2.5 text-sm font-semibold text-white transition-all duration-300 hover:-translate-y-0.5 hover:shadow-md"
        >
          ⭐ Star on GitHub
        </a>
      </section>
    </div>
  );
}
