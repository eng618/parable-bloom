import { Badge } from '@gv-tech/ui-web/badge';
import { Separator } from '@gv-tech/ui-web/separator';
import { Text } from '@gv-tech/ui-web/text';
import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Scripture Attributions',
  description:
    'Bible translation licenses and attributions for Parable Bloom. NET Bible is the default; WEB, BSB, and KJV are also supported.',
};

// Keep in sync with apps/parable-bloom/assets/data/scripture_metadata.json
// (active translations only).
const translations = [
  {
    abbr: 'NET',
    name: 'NET Bible',
    publisher: 'Biblical Studies Press, L.L.C.',
    license: 'Gratis ministry use in free apps (verse text only, no notes)',
    notice:
      'Scripture quoted by permission. Quotations designated (NET) are from the NET Bible® copyright ©1996, 2019 by Biblical Studies Press, L.L.C. http://netbible.com All rights reserved.',
    infoUrl: 'https://netbible.com/copyright',
    badge: 'Default',
  },
  {
    abbr: 'WEB',
    name: 'World English Bible',
    publisher: 'Public Domain',
    license: 'Public domain — offline + commercial use allowed',
    notice: 'Scripture quotations marked (WEB) are from the World English Bible, which is in the public domain.',
    infoUrl: 'https://worldenglish.bible',
  },
  {
    abbr: 'BSB',
    name: 'Berean Standard Bible',
    publisher: 'BSB Publishing (Public Domain, CC0 2023)',
    license: 'Public domain (CC0) — offline + commercial use allowed',
    notice:
      "The Holy Bible, Berean Standard Bible, BSB is produced in cooperation with Bible Hub, Discovery Bible, OpenBible.com, and the Berean Bible Translation Committee. This text of God's Word has been dedicated to the public domain.",
    infoUrl: 'https://berean.bible/terms.htm',
  },
  {
    abbr: 'KJV',
    name: 'King James Version',
    publisher: 'Public Domain (Crown Copyright in the UK)',
    license: 'Public domain worldwide; Crown copyright applies in the UK',
    notice: 'Scripture quotations are from the King James Version (KJV) Bible. Public domain.',
    infoUrl: 'https://www.cambridge.org/bibles/about/rights-and-permissions',
    badge: 'Fallback',
  },
];

export default function AttributionsPage() {
  return (
    <article className="page-article animate-fade-in-up">
      <div className="mb-6 flex flex-wrap items-center gap-3">
        <span className="text-4xl">📖</span>
        <div>
          <h1 className="font-display text-text-primary text-3xl font-bold sm:text-4xl">Scripture Attributions</h1>
          <Badge variant="secondary" className="border-brand/20 bg-brand/10 text-brand mt-1">
            Parable Bloom
          </Badge>
        </div>
      </div>

      <Separator className="mb-6 opacity-40" />

      <section className="mb-6">
        <Text variant="body" className="text-text-secondary">
          Parable Bloom is free and shows a single preferred translation everywhere in the app (change it in Settings →
          Scripture). The app bundle ships NET + KJV only to stay small; WEB and BSB download once on demand, then work
          offline. Every verse citation (e.g. Luke 8:11 (NET)) opens its full notice in the app.
        </Text>
      </section>

      <section className="mb-6 space-y-4">
        {translations.map((t) => (
          <div key={t.abbr} className="border-border/40 bg-bg-card rounded-2xl border p-5">
            <div className="mb-2 flex flex-wrap items-center gap-2">
              <h2 className="font-display text-text-primary text-lg font-semibold">
                {t.name} ({t.abbr})
              </h2>
              {t.badge ? (
                <Badge variant="secondary" className="border-brand/20 bg-brand/10 text-brand">
                  {t.badge}
                </Badge>
              ) : null}
            </div>
            <Text variant="body" className="text-text-secondary mb-1">
              Publisher: {t.publisher}
            </Text>
            <Text variant="body" className="text-text-secondary mb-2">
              License: {t.license}
            </Text>
            <Text variant="body" className="text-text-secondary mb-2 italic">
              {t.notice}
            </Text>
            <Text variant="body">
              <a
                href={t.infoUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="text-brand decoration-brand/40 hover:decoration-brand underline underline-offset-2 transition-colors"
              >
                License details
              </a>
            </Text>
          </div>
        ))}
      </section>

      <section className="mb-6">
        <h2 className="font-display text-text-primary mb-3 text-xl font-semibold">Donations & non-commercial use</h2>
        <Text variant="body" className="text-text-secondary">
          Parable Bloom is free with no ads, paywalls, or locked verses. Optional donations via Buy Me a Coffee on this
          site support general development only and never gate scripture content, preserving gratis ministry use of the
          NET Bible.
        </Text>
      </section>

      <section>
        <h2 className="font-display text-text-primary mb-3 text-xl font-semibold">Related Pages</h2>
        <ul className="space-y-2">
          <li>
            <Text variant="body">
              <Link
                href="/about"
                className="text-brand decoration-brand/40 hover:decoration-brand underline underline-offset-2 transition-colors"
              >
                About
              </Link>
            </Text>
          </li>
          <li>
            <Text variant="body">
              <Link
                href="/support"
                className="text-brand decoration-brand/40 hover:decoration-brand underline underline-offset-2 transition-colors"
              >
                Support
              </Link>
            </Text>
          </li>
        </ul>
      </section>
    </article>
  );
}
