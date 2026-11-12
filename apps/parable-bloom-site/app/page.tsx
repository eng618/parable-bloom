import { Text } from '@gv-tech/ui-web/text';
import type { Metadata } from 'next';
import Image from 'next/image';
import Link from 'next/link';

import DesignSystemCard from '@/components/design-system-card';
import LeafDivider from '@/components/leaf-divider';
import PhoneShot from '@/components/phone-shot';
import Reveal from '@/components/reveal';

export const metadata: Metadata = {
  title: { absolute: 'Parable Bloom' },
  description:
    'A calm Christ-centered arrow puzzle. Clear 500+ garden levels by sliding vines, then meet Scripture and reflection along the way.',
  alternates: { canonical: '/' },
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
    body: 'Join the open test on Google Play and install the Android app.',
    href: 'https://play.google.com/store/apps/details?id=com.garciaericn.parable_bloom',
    ctaLabel: 'Get on Google Play',
    badge: 'Available',
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
    objectPosition: 'center',
  },
  {
    src: '/screenshots/gameplay-tutorial.jpg',
    alt: 'Tutorial puzzle teaching tap-to-slide vine controls',
    caption: 'Play',
    objectPosition: 'center',
  },
  {
    src: '/screenshots/level-complete.jpg',
    alt: 'Level complete parchment card with encouraging message',
    caption: 'Bloom',
    objectPosition: 'center',
  },
  {
    src: '/screenshots/journal.jpg',
    alt: 'Scripture journal with NET passages unlocked by progress',
    caption: 'Journal',
    objectPosition: 'top',
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
      <section className="relative -mx-4 overflow-hidden sm:-mx-6">
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
          <Reveal className="relative z-10 max-w-xl">
            <p className="font-display text-brand mb-3 text-base italic">Gospel through games</p>
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
                className="cta-primary focus-visible:ring-brand/40 !text-on-brand hover:!text-on-brand focus-visible:ring-2 focus-visible:outline-none"
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
          </Reveal>

          <Reveal delay={180} className="relative mx-auto w-full max-w-[280px] sm:max-w-[320px] lg:max-w-[340px]">
            <PhoneShot
              src="/screenshots/home-welcome.jpg"
              alt="Parable Bloom home — wooden cross on parchment with botanical frame"
              objectPosition="center"
              priority
              sizes="(min-width: 1024px) 340px, 80vw"
              float
            />
          </Reveal>
        </div>
      </section>

      <section aria-label="Product screenshots">
        <Reveal>
          <h2 className="font-display text-text-primary text-2xl font-semibold sm:text-3xl">Inside the garden</h2>
          <p className="text-text-secondary mt-2 max-w-xl text-base">
            Home, puzzles, level blooms, and a Scripture journal — one calm visual language from first open to next-day
            welcome-back.
          </p>
          <LeafDivider />
        </Reveal>
        <div className="grid grid-cols-2 items-start gap-4 md:grid-cols-4 md:gap-5">
          {gallery.map((shot, index) => (
            <Reveal key={shot.src} as="figure" delay={index * 100}>
              <PhoneShot src={shot.src} alt={shot.alt} objectPosition={shot.objectPosition} />
              <figcaption className="font-display text-text-secondary mt-3 text-center text-sm tracking-wide">
                {shot.caption}
              </figcaption>
            </Reveal>
          ))}
        </div>
      </section>

      <section aria-label="Platform availability">
        <Reveal>
          <h2 className="font-display text-text-primary mb-2 text-2xl font-semibold sm:text-3xl">Where to play</h2>
          <p className="text-text-secondary mb-6 max-w-xl">
            Play in the browser, or join the Android open test on Google Play. iOS is still on the way.
          </p>
        </Reveal>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          {platforms.map((platform, index) => (
            <Reveal key={platform.title} delay={index * 100} className="h-full">
              <DesignSystemCard
                marker={platform.marker}
                title={platform.title}
                body={platform.body}
                href={platform.href}
                ctaLabel={platform.ctaLabel}
                badge={platform.badge}
              />
            </Reveal>
          ))}
        </div>
      </section>

      <section aria-label="Game features">
        <Reveal>
          <h2 className="font-display text-text-primary mb-2 text-2xl font-semibold sm:text-3xl">
            Peace in the puzzle
          </h2>
          <p className="text-text-secondary mb-8 max-w-2xl">
            Premium, easy, habit-forming gospel-through-games — short sessions that leave room for Scripture and
            reflection.
          </p>
        </Reveal>
        <div className="grid grid-cols-1 gap-8 sm:grid-cols-2">
          {features.map((feature, index) => (
            <Reveal key={feature.title} delay={index * 90} className="border-brand/15 border-t pt-5">
              <h3 className="font-display text-brand mb-2 text-xl font-semibold">{feature.title}</h3>
              <p className="text-text-secondary text-base leading-relaxed">{feature.body}</p>
            </Reveal>
          ))}
        </div>
      </section>

      <Reveal
        as="section"
        className="border-brand/15 bg-surface relative overflow-hidden rounded-[1.5rem] border px-6 py-10 text-center sm:px-10"
      >
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
            className="cta-primary !text-on-brand hover:!text-on-brand"
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
      </Reveal>
    </div>
  );
}
