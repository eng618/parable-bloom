import { Badge } from '@gv-tech/ui-web/badge';
import { Separator } from '@gv-tech/ui-web/separator';
import { Text } from '@gv-tech/ui-web/text';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'About',
  description:
    'Learn about Parable Bloom — a calm Christ-centered arrow puzzle with 500+ garden levels, Scripture journal, and offline play.',
};

export default function AboutPage() {
  return (
    <article className="page-article animate-fade-in-up">
      <div className="mb-6 flex flex-wrap items-center gap-3">
        <div>
          <h1 className="font-display text-brand text-3xl font-semibold sm:text-4xl">About</h1>
          <Badge variant="secondary" className="border-brand/20 bg-brand/10 text-brand mt-2">
            Parable Bloom
          </Badge>
        </div>
      </div>

      <Separator className="mb-6 opacity-40" />

      <section className="mb-6">
        <h2 className="font-display text-text-primary mb-3 text-xl font-semibold">Overview</h2>
        <Text variant="body" className="text-text-secondary">
          Parable Bloom is a Christ-centered arrow puzzle. Tap free vines so they slide off the board, clear each garden,
          and unlock Scripture (NET primary) plus reflection prompts in your Journal along the way.
        </Text>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-text-primary mb-3 text-xl font-semibold">What you&apos;ll find</h2>
        <ul className="text-text-secondary list-disc space-y-2 pl-5">
          <li>
            <strong className="text-text-primary">500+ puzzles</strong> across 24 modules, plus 5 guided lessons
          </li>
          <li>
            A parchment garden look in light and moonlit dark modes — forest primary, sage accents, serif brand titles
          </li>
          <li>Offline play, with optional cloud sync when you sign in</li>
          <li>Scripture translations: NET default, with WEB, BSB, and KJV available where licensing allows</li>
        </ul>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-text-primary mb-3 text-xl font-semibold">Development</h2>
        <Text variant="body" className="text-text-secondary">
          Built with Flutter and Flame for a cross-platform experience on Web, Android, and iOS.
        </Text>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-text-primary mb-3 text-xl font-semibold">Download</h2>
        <ul className="space-y-2">
          <li>
            <Text variant="body">
              <a
                href="https://parable-bloom.web.app/"
                className="text-brand decoration-brand/40 hover:decoration-brand underline underline-offset-2 transition-colors"
              >
                Play on Web
              </a>{' '}
              <span className="text-text-secondary">(available now)</span>
            </Text>
          </li>
          <li>
            <Text variant="body">
              <a
                href="https://play.google.com/store/apps/details?id=com.garciaericn.parable_bloom"
                className="text-brand decoration-brand/40 hover:decoration-brand underline underline-offset-2 transition-colors"
              >
                Get it on Google Play
              </a>{' '}
              <span className="text-text-secondary">(Coming Soon)</span>
            </Text>
          </li>
        </ul>
      </section>

      <section>
        <h2 className="font-display text-text-primary mb-3 text-xl font-semibold">Contact</h2>
        <ul className="space-y-2">
          <li>
            <Text variant="body">
              <a
                href="mailto:parablebloom.support@garciaericn.com"
                className="text-brand decoration-brand/40 hover:decoration-brand underline underline-offset-2 transition-colors"
              >
                parablebloom.support@garciaericn.com
              </a>
            </Text>
          </li>
          <li>
            <Text variant="body">
              GitHub:{' '}
              <a
                href="https://github.com/eng618/parable-bloom"
                className="text-brand decoration-brand/40 hover:decoration-brand underline underline-offset-2 transition-colors"
              >
                eng618/parable-bloom
              </a>
            </Text>
          </li>
        </ul>
      </section>
    </article>
  );
}
