import { Badge } from '@gv-tech/ui-web/badge';
import { Separator } from '@gv-tech/ui-web/separator';
import { Text } from '@gv-tech/ui-web/text';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Delete Account',
  description: 'Instructions on how to delete your Parable Bloom account and associated data.',
  robots: 'noindex',
};

export default function DeleteAccountPage() {
  return (
    <article className="page-article animate-fade-in-up">
      <div className="mb-6 flex flex-wrap items-center gap-3">
        <span className="animate-float text-4xl">🗑️</span>
        <div>
          <h1 className="font-display text-foreground text-3xl font-bold sm:text-4xl">Deleting Your Account</h1>
          <Badge variant="secondary" className="border-border bg-muted/60 text-muted-foreground mt-1">
            Data Privacy
          </Badge>
        </div>
      </div>

      <Separator className="mb-6 opacity-40" />

      <Text variant="body" className="text-muted-foreground mb-6 leading-relaxed">
        We respect your data privacy. If you wish to delete your account and all associated data, choose one of the
        following options.
      </Text>

      <section className="mb-8">
        <h2 className="font-display text-foreground mb-3 text-xl font-semibold">
          Option 1: Delete via the App (Recommended)
        </h2>
        <ol className="text-muted-foreground list-inside list-decimal space-y-2">
          <li>
            <span>Open Parable Bloom on your device.</span>
          </li>
          <li>
            <span>Navigate to the Settings screen (represented by the gear icon).</span>
          </li>
          <li>
            <span>Find the Account Management section.</span>
          </li>
          <li>
            <span>
              Select <strong>Delete Account</strong>.
            </span>
          </li>
          <li>
            <span>Read the confirmation prompt and confirm your deletion.</span>
          </li>
        </ol>
        <Text variant="bodySmall" className="text-muted-foreground mt-3 italic">
          Your account details will be permanently and immediately removed from our systems.
        </Text>
      </section>

      <section className="border-border/60 bg-muted/30 dark:bg-muted/10 rounded-2xl border p-5">
        <h2 className="font-display text-foreground mb-2 text-xl font-semibold">
          Option 2: Request Deletion via Email (Web-based)
        </h2>
        <Text variant="body" className="text-muted-foreground mb-3 leading-relaxed">
          If you no longer have the app installed or cannot access it, you can submit a web-based request for account
          deletion via email:
        </Text>
        <div className="bg-card border-border/60 mb-3 rounded-xl border p-3">
          <Text variant="bodySmall" className="text-foreground">
            <strong>Email:</strong>{' '}
            <a
              href="mailto:parablebloom.account+delete@garciaericn.com"
              className="text-brand font-medium hover:underline"
            >
              parablebloom.account+delete@garciaericn.com
            </a>
          </Text>
        </div>
        <Text variant="caption" className="text-muted-foreground block leading-relaxed">
          Note: For security purposes, you must send this email from the same email address associated with your Parable
          Bloom account. We will process your request and permanently delete your data within 30 days.
        </Text>
      </section>
    </article>
  );
}
