import { Badge } from '@gv-tech/ui-web/badge';
import { Separator } from '@gv-tech/ui-web/separator';
import { Text } from '@gv-tech/ui-web/text';
import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description: 'Read the privacy policy for Parable Bloom, detailing how we collect, use, and protect your data.',
};

export default function PrivacyPage() {
  return (
    <article className="page-article animate-fade-in-up">
      <div className="mb-6 flex flex-wrap items-center gap-3">
        <span className="animate-float text-4xl">🔒</span>
        <div>
          <h1 className="font-display text-foreground text-3xl font-bold sm:text-4xl">Privacy Policy</h1>
          <div className="mt-1 flex items-center gap-2">
            <Badge variant="secondary" className="border-border bg-muted/60 text-muted-foreground text-xs">
              Effective: Feb 04, 2026
            </Badge>
            <Badge variant="secondary" className="border-border bg-muted/60 text-muted-foreground text-xs">
              Updated: March 13, 2026
            </Badge>
          </div>
        </div>
      </div>

      <Separator className="mb-6 opacity-40" />

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">1. Introduction</h2>
        <Text variant="body" className="text-muted-foreground mb-3 leading-relaxed">
          Welcome to <strong>Parable Bloom</strong>. At <strong>GVTech</strong> (&quot;we,&quot; &quot;us,&quot; or
          &quot;our&quot;), we respect your privacy and are committed to protecting the personal information you may
          provide to us. This Privacy Policy explains how we collect, use, and safeguard your information when you use
          our mobile application, <strong>Parable Bloom</strong>.
        </Text>
        <Text variant="body" className="text-muted-foreground leading-relaxed">
          Our mission is to provide a peaceful, prayerful, and faith-based gaming experience. We believe that your
          digital peace of mind is just as important as your spiritual growth in Christ. Therefore, we design our
          services to collect the absolute minimum amount of data necessary to function and improve the game.
        </Text>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">2. Information We Collect</h2>
        <Text variant="body" className="text-muted-foreground mb-4 leading-relaxed">
          We prioritize your privacy and collect the minimum Personal Identifiable Information (PII) necessary. If you
          choose to create an account, we collect your email address; otherwise, data is collected anonymously.
        </Text>

        <h3 className="font-display text-foreground mb-2 text-lg font-medium">2.1 Telemetry &amp; Analytics</h3>
        <Text variant="body" className="text-muted-foreground mb-3 leading-relaxed">
          To help us improve the game&apos;s stability and gameplay experience, we use analytics tools (specifically{' '}
          <strong>Google Firebase Analytics</strong> and <strong>Openpanel</strong>) to automatically collect certain
          anonymous technical information. This data is <strong>aggregated and anonymized</strong>, meaning it is not
          linked to your identity. Openpanel is self-hosted on GVTech infrastructure (openpanel.gventureshq.com), so
          telemetry remains under our direct control, uses no third-party tracking cookies, and stores no personal data.
        </Text>
        <ul className="text-muted-foreground mb-4 list-inside list-disc space-y-1.5">
          <li>
            <strong>Usage Data</strong>: Details about level completion rates, button taps, and session duration.
          </li>
          <li>
            <strong>Device Information</strong>: Operating system version and general region (anonymized IP).
          </li>
          <li>
            <strong>Crash &amp; Performance Reports</strong>: Anonymous logs to resolve technical issues.
          </li>
        </ul>

        <h3 className="font-display text-foreground mb-2 text-lg font-medium">2.2 Account Information</h3>
        <Text variant="body" className="text-muted-foreground mb-3 leading-relaxed">
          If you choose to create an account, we collect:
        </Text>
        <ul className="text-muted-foreground list-inside list-disc space-y-1.5">
          <li>
            <strong>Email Address &amp; Password</strong>: Managed securely via Firebase Authentication.
          </li>
          <li>
            <strong>User ID</strong>: A unique identifier generated to sync game progress across devices.
          </li>
        </ul>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">3. How We Use Your Information</h2>
        <ul className="text-muted-foreground list-inside list-disc space-y-2">
          <li>
            <strong>Account Management</strong>: To secure your account and save your game progress.
          </li>
          <li>
            <strong>Operation &amp; Maintenance</strong>: Ensuring smooth performance across devices.
          </li>
          <li>
            <strong>Game Improvements</strong>: Balancing level difficulty and fixing bugs.
          </li>
          <li>
            <strong>Communication</strong>: Responding to support inquiries if you reach out to us.
          </li>
        </ul>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">4. Third-Party Service Providers</h2>
        <ul className="text-muted-foreground list-inside list-disc space-y-2">
          <li>
            <strong>Google Firebase</strong>: Analytics and crash reporting ({' '}
            <a
              href="https://policies.google.com/privacy"
              target="_blank"
              rel="noopener noreferrer"
              className="text-brand hover:underline"
            >
              Google Privacy &amp; Terms
            </a>
            ).
          </li>
          <li>
            <strong>Openpanel (self-hosted)</strong>: Anonymous gameplay event tracking without tracking cookies or
            personal data.
          </li>
        </ul>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">5. Children&apos;s Privacy</h2>
        <Text variant="body" className="text-muted-foreground leading-relaxed">
          <strong>Parable Bloom</strong> does not knowingly collect personally identifiable information from children
          under 13. If you become aware that a child has provided us with personal data, please contact us for immediate
          deletion.
        </Text>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">6. Your Data Rights</h2>
        <Text variant="body" className="text-muted-foreground leading-relaxed">
          You can delete your account and associated data directly in the app via{' '}
          <strong>Settings &gt; Delete Account</strong>, or request deletion via our{' '}
          <Link href="/delete-account" className="text-brand hover:underline">
            Account Deletion Page
          </Link>
          .
        </Text>
      </section>

      <section>
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">7. Contact Us</h2>
        <Text variant="body" className="text-muted-foreground leading-relaxed">
          For any privacy questions or requests, contact us at:{' '}
          <a href="mailto:parablebloom.support@garciaericn.com" className="text-brand font-medium hover:underline">
            parablebloom.support@garciaericn.com
          </a>
        </Text>
      </section>
    </article>
  );
}
