import { Text } from '@gv-tech/ui-web';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Delete Account - Parable Bloom',
  description: 'Instructions on how to delete your Parable Bloom account and associated data.',
  robots: 'noindex',
};

export default function DeleteAccountPage() {
  return (
    <article className="page">
      <Text variant="h1">Deleting Your Parable Bloom Account</Text>
      <Text variant="body">
        We respect your data privacy. If you wish to delete your account and all associated data, choose one of the
        following options.
      </Text>

      <Text variant="h2">Option 1: Delete via the App (Recommended)</Text>
      <ol>
        <li>
          <Text variant="body">Open Parable Bloom on your device.</Text>
        </li>
        <li>
          <Text variant="body">Navigate to the Settings screen (represented by the gear icon).</Text>
        </li>
        <li>
          <Text variant="body">Find the Account Management section.</Text>
        </li>
        <li>
          <Text variant="body">Select Delete Account.</Text>
        </li>
        <li>
          <Text variant="body">Read the confirmation prompt and confirm your deletion.</Text>
        </li>
      </ol>
      <Text variant="body">Your account details will be permanently and immediately removed from our systems.</Text>

      <Text variant="h2">Option 2: Request Deletion via Email (Web-based)</Text>
      <Text variant="body">
        If you no longer have the app installed or cannot access it, you can submit a web-based request for account
        deletion via email.
      </Text>
      <Text variant="body">
        Please send an email to our data deletion request address with the subject line "Account Deletion Request":
      </Text>
      <Text variant="body">
        <strong>Email:</strong> parablebloom.account+delete@garciaericn.com
      </Text>
      <Text variant="body">
        <em>
          Note: For security purposes, you must send this email from the same email address associated with your Parable
          Bloom account. We will process your request and permanently delete your data within 30 days.
        </em>
      </Text>
    </article>
  );
}
