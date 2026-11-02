import { Text } from '@gv-tech/ui-web/text';
import type { Metadata } from 'next';
import Image from 'next/image';
import Link from 'next/link';

import DesignSystemCard from '@/components/design-system-card';

export const metadata: Metadata = {
  title: 'Parable Bloom',
  description:
    'A calm Christ-centered arrow puzzle. Clear 500+ garden levels by sliding vines, then meet Scripture and reflection along the way.',
};

const platforms = [
  {
    marker: 'Web',
    title: 'Play on Web',
    body: 'Open the garden in your browser — no download required.',
    href: 'https://parable-bloom.web.app/',
    ctaLabel: 'Play Now',
    badge: 'Available',
  },
  {
    marker: 'Android',
    title: 'Android',
    body: 'The full mobile experience on Google Play.',
    href: 'https://play.google.com/store/apps/details?id=com.garciaericn.parable_bloom',
    ctaLabel: 'Get on Google Play',
    badge: 'Coming Soon',
  },
  {
    marker: 'iOS',
    title: 'iOS',
    body: 'Coming to iPhone and iPad.',
    href: undefined,
    ctaLabel: 'App Store soon',
    badge: 'Coming Soon',
  },
];

const gallery = [
  {
    src: '/screenshots/home-welcome.jpg',
    alt: 'Parable Bloom home screen with wooden cross and Play Level button',
    caption: 'Home',
  },
  {
    src: '/screenshots/gameplay-tutorial.jpg',
    alt: 'Tutorial puzzle teaching tap-to-slide vine controls',
    caption: 'Play',
  },
  {
    src: '/screenshots/level-complete.jpg',
    alt: 'Level complete parchment card with encouraging message',
    caption: 'Bloom',
  },
  {
    src: '/screenshots/journal.jpg',
    alt: 'Scripture journal with NET passages unlocked by progress',
    caption: 'Journal',
  },
];

const features = [
  {
    title: 'Tap & slide vines',
    body: 'Clear each garden board by sliding free vines off the grid — intuitive in minutes, rich for hundreds of levels.',
  },
  {
    title: '500+ garden puzzles',
    body: 'Twenty-four modules from Seedling onward, plus five guided lessons that grow into fuller vine density.',
  },
  {
    title: 'Scripture along the way',
    body: 'Unlock NET passages and reflection prompts in your Journal as you progress — gospel as reward, not interruption.',
  },
  {
    title: 'Calm offline play',
    body: 'Serene parchment gardens, light and moonlit dark modes, and offline play whenever you need a quiet moment.',
  },
];

export default function HomePage() {
  return (
    <div className="flex flex-col gap-16 pb-12 sm:gap-20">
      {/* ── Hero: brand + headline + CTA + dominant product image ── */}
      {/* Break out of main padding without w-screen (avoids horizontal overflow / clipped header) */}
      <section className="relative -mx-4 overflow-hidden sm:-mx-6">
        {/* Soft corner sprigs only — punched PNG alpha, no full-bleed frame matte */}
        <Image
          src="/art/leaf_sprig.png"
          alt=""
          width={120}
          height={134}
          aria-hidden="true"
          className="pointer-events-none absolute top-6 left-2 opacity-80 sm:top-10 sm:left-6"
        />
        <Image
          src="/art/leaf_sprig.png"
          alt=""
          width={120}
          height={134}
          aria-hidden="true"
          className="pointer-events-none absolute right-2 bottom-8 scale-x-[-1] opacity-80 sm:right-8 sm:bottom-12"
        />
        <div className="relative mx-auto grid w-full max-w-6xl items-center gap-10 px-4 py-10 sm:px-6 sm:py-14 lg:grid-cols-[minmax(0,1.05fr)_minmax(0,0.95fr)] lg:gap-12 lg:py-16">
          <div className="animate-fade-in-up relative z-10 max-w-xl">
            <p className="font-display text-brand mb-3 text-sm tracking-[0.08em] uppercase">Gospel through games</p>
            <h1 className="font-display text-brand mb-4 text-5xl leading-[1.05] font-semibold tracking-tight sm:text-6xl lg:text-7xl">
              Parable Bloom
            </h1>
            <p className="font-display text-text-secondary mb-8 max-w-md text-lg leading-relaxed italic sm:text-xl">
              Clear the garden by sliding vines. Meet Scripture and quiet reflection along the path.
            </p>
            <div className="flex flex-wrap gap-3">
              <Link
                href="https://parable-bloom.web.app/"
                target="_blank"
                rel="noopener noreferrer"
                className="cta-primary focus-visible:ring-brand/40 !text-[#fffbf3] hover:!text-[#fffbf3] focus-visible:ring-2 focus-visible:outline-none"
              >
                Play on Web
              </Link>
              <Link
                href="https://play.google.com/store/apps/details?id=com.garciaericn.parable_bloom"
                target="_blank"
                rel="noopener noreferrer"
                className="cta-secondary focus-visible:ring-brand/30 focus-visible:ring-2 focus-visible:outline-none"
              >
                Google Play
              </Link>
            </div>
          </div>

          <div className="animate-soft-rise animation-delay-200 relative mx-auto w-full max-w-[280px] sm:max-w-[320px] lg:max-w-[360px]">
            <div className="phone-frame animate-float">
              <Image
                src="/screenshots/home-welcome.jpg"
                alt="Parable Bloom home — wooden cross on parchment with botanical frame"
                width={780}
                height={1387}
                priority
                className="h-auto w-full"
              />
            </div>
          </div>
        </div>
      </section>

      {/* ── Product gallery ── */}
      <section aria-label="Product screenshots" className="animate-fade-in-up">
        <div className="mb-2 flex items-end justify-between gap-4">
          <div>
            <h2 className="font-display text-text-primary text-2xl font-semibold sm:text-3xl">Inside the garden</h2>
            <p className="text-text-secondary mt-2 max-w-xl text-base">
              Home, puzzles, level blooms, and a Scripture journal — one calm visual language from first open to next-day
              welcome-back.
            </p>
          </div>
        </div>
        <div className="leaf-divider" aria-hidden="true">
          <Image src="/art/leaf_pair.png" alt="" width={72} height={24} className="opacity-90" />
        </div>
        <div className="grid grid-cols-2 gap-4 md:grid-cols-4 md:gap-5">
          {gallery.map((shot, i) => (
            <figure
              key={shot.src}
              className="animate-fade-in-up"
              style={{ animationDelay: `${i * 90}ms` }}
            >
              <div className="phone-frame">
                <Image src={shot.src} alt={shot.alt} width={540} height={1100} className="h-auto w-full" />
              </div>
              <figcaption className="font-display text-text-secondary mt-3 text-center text-sm tracking-wide">
                {shot.caption}
              </figcaption>
            </figure>
          ))}
        </div>
      </section>

      {/* ── Platforms ── */}
      <section aria-label="Platform availability">
        <h2 className="font-display text-text-primary mb-2 text-2xl font-semibold sm:text-3xl">Where to play</h2>
        <p className="text-text-secondary mb-6 max-w-xl">
          Start in the browser today. Mobile store listings follow as releases land.
        </p>
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

      {/* ── Features ── */}
      <section aria-label="Game features">
        <h2 className="font-display text-text-primary mb-2 text-2xl font-semibold sm:text-3xl">
          Peace in the puzzle
        </h2>
        <p className="text-text-secondary mb-8 max-w-2xl">
          Premium, easy, habit-forming gospel-through-games — short sessions that leave room for Scripture and
          reflection.
        </p>
        <div className="grid grid-cols-1 gap-8 sm:grid-cols-2">
          {features.map((feature, i) => (
            <div
              key={feature.title}
              className="animate-fade-in-up border-brand/15 border-t pt-5"
              style={{ animationDelay: `${i * 80}ms` }}
            >
              <h3 className="font-display text-brand mb-2 text-xl font-semibold">{feature.title}</h3>
              <p className="text-text-secondary text-base leading-relaxed">{feature.body}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── Closing CTA ── */}
      <section className="animate-fade-in-up relative overflow-hidden rounded-[1.5rem] border border-brand/15 bg-surface px-6 py-10 text-center sm:px-10">
        <Image
          src="/art/leaf_sprig.png"
          alt=""
          width={80}
          height={48}
          className="mx-auto mb-4 opacity-90"
          aria-hidden="true"
        />
        <h2 className="font-display text-brand mb-3 text-3xl font-semibold">Step into the garden</h2>
        <Text variant="body" className="text-text-secondary mx-auto mb-6 max-w-md">
          Follow development, star the repo, or open a quiet level right now.
        </Text>
        <div className="flex flex-wrap justify-center gap-3">
          <Link
            href="https://parable-bloom.web.app/"
            target="_blank"
            rel="noopener noreferrer"
            className="cta-primary !text-[#fffbf3] hover:!text-[#fffbf3]"
          >
            Play on Web
          </Link>
          <a
            href="https://github.com/eng618/parable-bloom"
            target="_blank"
            rel="noopener noreferrer"
            className="cta-secondary"
          >
            Star on GitHub
          </a>
        </div>
      </section>
    </div>
  );
}
