import { Badge } from '@gv-tech/ui-web/badge';
import { Separator } from '@gv-tech/ui-web/separator';
import { Text } from '@gv-tech/ui-web/text';
import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Terms of Service',
  description: 'Read the terms of service for Parable Bloom, outlining usage rights and responsibilities.',
};

export default function TermsPage() {
  return (
    <article className="page-article animate-fade-in-up">
      <div className="mb-6 flex flex-wrap items-center gap-3">
        <span className="animate-float text-4xl">📜</span>
        <div>
          <h1 className="font-display text-foreground text-3xl font-bold sm:text-4xl">Terms of Service</h1>
          <div className="mt-1 flex items-center gap-2">
            <Badge variant="secondary" className="border-border bg-muted/60 text-muted-foreground text-xs">
              Effective: Feb 04, 2026
            </Badge>
            <Badge variant="secondary" className="border-border bg-muted/60 text-muted-foreground text-xs">
              Updated: Feb 23, 2026
            </Badge>
          </div>
        </div>
      </div>

      <Separator className="mb-6 opacity-40" />

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">1. Acceptance of Terms</h2>
        <Text variant="body" className="text-muted-foreground leading-relaxed">
          By downloading, installing, or using <strong>Parable Bloom</strong> (&quot;App&quot;), you agree to be bound
          by these <strong>Terms of Service</strong> (&quot;Terms&quot;). If you do not agree to these Terms, please do
          not use the App. These Terms constitute a binding legal agreement between you and <strong>GVTech</strong>{' '}
          (&quot;we,&quot; &quot;us,&quot; &quot;our&quot;).
        </Text>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">2. License to Use</h2>
        <Text variant="body" className="text-muted-foreground leading-relaxed">
          Subject to your compliance with these Terms, GVTech grants you a limited, non-exclusive, non-transferable,
          revocable license to download, install, and use the App for your personal, non-commercial entertainment use on
          a mobile device that you own or control.
        </Text>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">3. Restrictions</h2>
        <Text variant="body" className="text-muted-foreground mb-3 leading-relaxed">
          You agree not to, and you will not permit others to:
        </Text>
        <ul className="text-muted-foreground list-inside list-disc space-y-2">
          <li>
            <strong>License, sell, rent, lease, assign, distribute, transmit, host, outsource, or disclose</strong> the
            App or make the App available to any third party.
          </li>
          <li>
            <strong>
              Modify, make derivative works of, disassemble, decrypt, reverse compile, or reverse engineer
            </strong>{' '}
            any part of the App.
          </li>
          <li>
            <strong>Remove, alter, or obscure</strong> any proprietary notice (including copyright or trademark notices)
            of GVTech or its licensors.
          </li>
        </ul>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">4. Updates and Telemetry</h2>
        <Text variant="body" className="text-muted-foreground leading-relaxed">
          We may provide enhancements or modifications to the App (&quot;Updates&quot;). You acknowledge that the App
          may automatically collect anonymous telemetry and crash reports as detailed in our{' '}
          <Link href="/privacy" className="text-brand hover:underline">
            Privacy Policy
          </Link>
          .
        </Text>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">5. Intellectual Property</h2>
        <Text variant="body" className="text-muted-foreground leading-relaxed">
          The App, including but not limited to all text, graphics, user interfaces, visual designs, audio, artwork, and
          code, is owned and controlled by GVTech, protected by intellectual property laws.
        </Text>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">6. Disclaimer of Warranties</h2>
        <Text variant="body" className="text-muted-foreground leading-relaxed">
          The App is provided to you &quot;AS IS&quot; and &quot;AS AVAILABLE&quot; without warranty of any kind. To the
          maximum extent permitted under applicable law, GVTech expressly disclaims all warranties, express or implied.
        </Text>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">7. Limitation of Liability</h2>
        <Text variant="body" className="text-muted-foreground leading-relaxed">
          To the fullest extent permitted by applicable law, in no event shall GVTech or its suppliers be liable for any
          special, incidental, indirect, or consequential damages arising out of the use of the App.
        </Text>
      </section>

      <section className="mb-6">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">8. Governing Law</h2>
        <Text variant="body" className="text-muted-foreground leading-relaxed">
          The laws of the United States govern this Agreement and your use of the Application.
        </Text>
      </section>

      <section>
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">9. Contact Information</h2>
        <Text variant="body" className="text-muted-foreground leading-relaxed">
          If you have questions about these Terms, please contact us at:{' '}
          <a href="mailto:parablebloom.support@garciaericn.com" className="text-brand font-medium hover:underline">
            parablebloom.support@garciaericn.com
          </a>
        </Text>
      </section>
    </article>
  );
}
