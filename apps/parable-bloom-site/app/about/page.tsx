import { Badge } from '@gv-tech/ui-web/badge';
import { Separator } from '@gv-tech/ui-web/separator';
import { Text } from '@gv-tech/ui-web/text';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'About',
  description: 'Learn more about Parable Bloom, a Christ-centered arrow puzzle game of faith, scripture, and prayer.',
};

export default function AboutPage() {
  return (
    <article className="page-article animate-fade-in-up">
      <div className="mb-6 flex flex-wrap items-center gap-3">
        <span className="animate-float text-4xl">🌿</span>
        <div>
          <h1 className="font-display text-foreground text-3xl font-bold sm:text-4xl">About</h1>
          <Badge variant="secondary" className="border-brand/20 bg-brand/10 text-brand dark:bg-brand/20 mt-1">
            Parable Bloom
          </Badge>
        </div>
      </div>

      <Separator className="mb-6 opacity-40" />

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">Overview</h2>
        <Text variant="body" className="text-muted-foreground leading-relaxed">
          Parable Bloom is a Christ-centered arrow puzzle game. Guide vines through gardens of grace while uncovering
          the parables of Jesus.
        </Text>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">Development</h2>
        <Text variant="body" className="text-muted-foreground leading-relaxed">
          Built with Flutter and Flame for a cross-platform gaming experience available on Web, Android, and iOS.
        </Text>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">Download</h2>
        <ul className="space-y-2.5">
          <li className="flex items-center gap-2.5">
            <span className="text-xl">🤖</span>
            <Text variant="body">
              <a
                href="https://play.google.com/store/apps/details?id=com.garciaericn.parable_bloom"
                className="text-brand font-medium underline-offset-2 transition-colors hover:underline"
              >
                Get it on Google Play
              </a>{' '}
              <span className="text-muted-foreground text-sm">(Coming Soon)</span>
            </Text>
          </li>
          <li className="flex items-center gap-2.5">
            <span className="text-xl">🌐</span>
            <Text variant="body">
              <a
                href="https://parable-bloom.web.app/"
                target="_blank"
                rel="noopener noreferrer"
                className="text-brand font-medium underline-offset-2 transition-colors hover:underline"
              >
                Play Instantly on Web
              </a>
            </Text>
          </li>
        </ul>
      </section>

      <section>
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">Contact</h2>
        <ul className="space-y-2.5">
          <li className="flex items-center gap-2.5">
            <span className="text-xl">✉️</span>
            <Text variant="body">
              <a
                href="mailto:parablebloom.support@garciaericn.com"
                className="text-brand font-medium underline-offset-2 transition-colors hover:underline"
              >
                parablebloom.support@garciaericn.com
              </a>
            </Text>
          </li>
          <li className="flex items-center gap-2.5">
            <span className="text-xl">💻</span>
            <Text variant="body">
              GitHub:{' '}
              <a
                href="https://github.com/eng618/parable-bloom"
                target="_blank"
                rel="noopener noreferrer"
                className="text-brand font-medium underline-offset-2 transition-colors hover:underline"
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
