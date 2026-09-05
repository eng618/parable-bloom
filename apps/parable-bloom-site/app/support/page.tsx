import { Badge } from '@gv-tech/ui-web/badge';
import { Separator } from '@gv-tech/ui-web/separator';
import { Text } from '@gv-tech/ui-web/text';
import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Support',
  description: 'Get help with Parable Bloom: contact support, FAQs, and links to privacy, terms, and account deletion.',
};

const faqs = [
  {
    question: 'Which platforms are supported?',
    answer:
      'Parable Bloom is available on Web (play instantly in your browser) and Android via Google Play. iOS support is coming soon.',
  },
  {
    question: 'Do I need an internet connection to play?',
    answer:
      'No. Gameplay works offline. An internet connection is only needed for account sync, cloud saves, and over-the-air content updates.',
  },
  {
    question: 'Which Bible translations are supported?',
    answer:
      'NET Bible is the default (modern and readable), with WEB, BSB, and KJV available in Settings → Scripture. Your choice applies everywhere instantly. The app ships NET + KJV only; WEB and BSB download once, then work offline. See our attributions page for full license notices.',
  },
  {
    question: 'How does the Grace system work?',
    answer:
      'Each level grants 3 Grace (4 on Transcendent difficulty). Blocked vines animate back with encouragement instead of ending your run — tap a vine to try a different path.',
  },
  {
    question: 'How do I delete my account and data?',
    answer:
      'Use Settings > Delete Account in the app, or follow the instructions on our account deletion page. Email requests are processed within 30 days.',
  },
];

export default function SupportPage() {
  return (
    <article className="page-article animate-fade-in-up">
      <div className="mb-6 flex flex-wrap items-center gap-3">
        <span className="text-4xl">💬</span>
        <div>
          <h1 className="font-display text-text-primary text-3xl font-bold sm:text-4xl">Support</h1>
          <Badge variant="secondary" className="border-brand/20 bg-brand/10 text-brand mt-1">
            Parable Bloom
          </Badge>
        </div>
      </div>

      <Separator className="mb-6 opacity-40" />

      <section className="mb-6">
        <h2 className="font-display text-text-primary mb-3 text-xl font-semibold">Contact Us</h2>
        <Text variant="body" className="text-text-secondary">
          For help with gameplay, accounts, or anything else, email us at{' '}
          <a
            href="mailto:parablebloom.support@garciaericn.com"
            className="text-brand decoration-brand/40 hover:decoration-brand underline underline-offset-2 transition-colors"
          >
            parablebloom.support@garciaericn.com
          </a>
          . We aim to respond within a few business days. You can also report bugs or request features on{' '}
          <a
            href="https://github.com/eng618/parable-bloom/issues"
            target="_blank"
            rel="noopener noreferrer"
            className="text-brand decoration-brand/40 hover:decoration-brand underline underline-offset-2 transition-colors"
          >
            GitHub Issues
          </a>
          .
        </Text>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-text-primary mb-3 text-xl font-semibold">Frequently Asked Questions</h2>
        <div className="space-y-4">
          {faqs.map((faq) => (
            <div key={faq.question}>
              <h3 className="font-display text-text-primary mb-1 font-semibold">{faq.question}</h3>
              <Text variant="body" className="text-text-secondary">
                {faq.answer}
              </Text>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="font-display text-text-primary mb-3 text-xl font-semibold">Related Pages</h2>
        <ul className="space-y-2">
          <li>
            <Text variant="body">
              <Link
                href="/privacy"
                className="text-brand decoration-brand/40 hover:decoration-brand underline underline-offset-2 transition-colors"
              >
                Privacy Policy
              </Link>
            </Text>
          </li>
          <li>
            <Text variant="body">
              <Link
                href="/terms"
                className="text-brand decoration-brand/40 hover:decoration-brand underline underline-offset-2 transition-colors"
              >
                Terms of Service
              </Link>
            </Text>
          </li>
          <li>
            <Text variant="body">
              <Link
                href="/delete-account"
                className="text-brand decoration-brand/40 hover:decoration-brand underline underline-offset-2 transition-colors"
              >
                Delete Your Account
              </Link>
            </Text>
          </li>
        </ul>
      </section>
    </article>
  );
}
