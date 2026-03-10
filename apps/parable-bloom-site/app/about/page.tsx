import { Badge, Separator, Text } from '@gv-tech/ui-web';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'About',
  description: 'Learn more about Parable Bloom, a zen hyper-casual arrow puzzle game with faith-based themes.',
};

export default function AboutPage() {
  return (
    <article className="page-article animate-fade-in-up">
      <div className="mb-6 flex flex-wrap items-center gap-3">
        <span className="text-4xl">🌿</span>
        <div>
          <h1 className="font-display text-text-primary text-3xl font-bold sm:text-4xl">About</h1>
          <Badge variant="secondary" className="border-brand/20 bg-brand/10 text-brand mt-1">
            Parable Bloom
          </Badge>
        </div>
      </div>

      <Separator className="mb-6 opacity-40" />

      <section className="mb-6">
        <h2 className="font-display text-text-primary mb-3 text-xl font-semibold">Overview</h2>
        <Text variant="body" className="text-text-secondary">
          Parable Bloom is a zen hyper-casual arrow puzzle game with faith-based themes. Guide vines through gardens
          while uncovering spiritual parables.
        </Text>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-text-primary mb-3 text-xl font-semibold">Development</h2>
        <Text variant="body" className="text-text-secondary">
          Built with Flutter and Flame for a cross-platform gaming experience available on Web, Android, and iOS.
        </Text>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-text-primary mb-3 text-xl font-semibold">Download</h2>
        <ul className="space-y-2">
          <li className="flex items-center gap-2">
            <span className="text-lg">🍏</span>
            <Text variant="body">
              <a
                href="https://apps.apple.com/app/parable-bloom"
                className="text-brand decoration-brand/40 hover:decoration-brand underline underline-offset-2 transition-colors"
              >
                Download on the App Store
              </a>{' '}
              <span className="text-text-secondary">(Coming Soon)</span>
            </Text>
          </li>
          <li className="flex items-center gap-2">
            <span className="text-lg">🤖</span>
            <Text variant="body">
              <a
                href="https://play.google.com/store/apps/details?id=com.garciaericn.parablebloom"
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
          <li className="flex items-center gap-2">
            <span className="text-lg">✉️</span>
            <Text variant="body">
              <a
                href="mailto:parablebloom.support@garciaericn.com"
                className="text-brand decoration-brand/40 hover:decoration-brand underline underline-offset-2 transition-colors"
              >
                parablebloom.support@garciaericn.com
              </a>
            </Text>
          </li>
          <li className="flex items-center gap-2">
            <span className="text-lg">💻</span>
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
