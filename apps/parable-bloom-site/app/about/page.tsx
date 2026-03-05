import { Text } from '@gv-tech/ui-web';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'About - Parable Bloom',
  description: 'Learn more about Parable Bloom, a zen hyper-casual arrow puzzle game with faith-based themes.',
};

export default function AboutPage() {
  return (
    <article className="page">
      <Text variant="h1">About</Text>

      <Text variant="h2">Overview</Text>
      <Text variant="body">
        Parable Bloom is a zen hyper-casual arrow puzzle game with faith-based themes. Guide vines through gardens while
        uncovering spiritual parables.
      </Text>

      <Text variant="h2">Development</Text>
      <Text variant="body">Built with Flutter and Flame for cross-platform gaming experience.</Text>

      <Text variant="h2">Download</Text>
      <ul>
        <li>
          <Text variant="body">
            <a href="https://apps.apple.com/app/parable-bloom">Download on the App Store</a> (Coming Soon)
          </Text>
        </li>
        <li>
          <Text variant="body">
            <a href="https://play.google.com/store/apps/details?id=com.garciaericn.parablebloom">
              Get it on Google Play
            </a>{' '}
            (Coming Soon)
          </Text>
        </li>
      </ul>

      <Text variant="h2">Contact</Text>
      <ul>
        <li>
          <Text variant="body">Email: parablebloom.support@garciaericn.com</Text>
        </li>
        <li>
          <Text variant="body">
            GitHub: <a href="https://github.com/eng618/parable-bloom">eng618/parable-bloom</a>
          </Text>
        </li>
      </ul>
    </article>
  );
}
