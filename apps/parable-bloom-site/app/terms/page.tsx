import { Text } from '@gv-tech/ui-web';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Terms of Service',
  description: 'Read the terms of service for Parable Bloom, outlining usage rights and responsibilities.',
};

export default function TermsPage() {
  return (
    <article className="page-article animate-fade-in-up">
      <Text variant="h1">Terms of Service</Text>
      <Text variant="body">
        <strong>Effective Date:</strong> February 04, 2026
      </Text>
      <Text variant="body">
        <strong>Last Updated:</strong> February 23, 2026
      </Text>

      <Text variant="h2">1. Acceptance of Terms</Text>
      <Text variant="body">
        By downloading, installing, or using <strong>Parable Bloom</strong> ("App"), you agree to be bound by these{' '}
        <strong>Terms of Service</strong> ("Terms"). If you do not agree to these Terms, please do not use the App.
        These Terms constitute a binding legal agreement between you and <strong>GVTech</strong> ("we," "us," "our").
      </Text>

      <Text variant="h2">2. License to Use</Text>
      <Text variant="body">
        Subject to your compliance with these Terms, GVTech grants you a limited, non-exclusive, non-transferable,
        revocable license to download, install, and use the App for your personal, non-commercial entertainment use on a
        mobile device that you own or control.
      </Text>

      <Text variant="h2">3. Restrictions</Text>
      <Text variant="body">You agree not to, and you will not permit others to:</Text>
      <ul>
        <li>
          <Text variant="body">
            <strong>
              License, sell, rent, lease, assign, distribute, transmit, host, outsource, disclose, or otherwise
              commercially exploit
            </strong>{' '}
            the App or make the App available to any third party.
          </Text>
        </li>
        <li>
          <Text variant="body">
            <strong>
              Modify, make derivative works of, disassemble, decrypt, reverse compile, or reverse engineer
            </strong>{' '}
            any part of the App.
          </Text>
        </li>
        <li>
          <Text variant="body">
            <strong>Remove, alter, or obscure</strong> any proprietary notice (including any notice of copyright or
            trademark) of GVTech or its affiliates, partners, suppliers, or the licensors of the App.
          </Text>
        </li>
      </ul>

      <Text variant="h2">4. Updates and Telemetry</Text>
      <Text variant="body">
        We may provide enhancements or improvements to the features/functionality of the App, which may include patches,
        bug fixes, updates, upgrades, and other modifications ("Updates").
      </Text>
      <Text variant="body">
        You acknowledge that the App may automatically collect anonymous usage statistics and crash reports
        ("Telemetry") to assist in the diagnosis of technical issues and the improvement of the user experience, as
        detailed in our <a href="/privacy">Privacy Policy</a>.
      </Text>

      <Text variant="h2">5. Intellectual Property</Text>
      <Text variant="body">
        The App, including but not limited to all text, graphics, user interfaces, visual interfaces, photographs,
        trademarks, logos, sounds, music, artwork, and computer code (collectively, "Content"), is owned, controlled, or
        licensed by or to GVTech, and is protected by trade dress, copyright, patent, and trademark laws, and various
        other intellectual property rights and unfair competition laws.
      </Text>

      <Text variant="h2">6. Disclaimer of Warranties</Text>
      <Text variant="body">
        The App is provided to you "AS IS" and "AS AVAILABLE" and with all faults and defects without warranty of any
        kind. To the maximum extent permitted under applicable law, GVTech, on its own behalf and on behalf of its
        affiliates and its and their respective licensors and service providers, expressly disclaims all warranties,
        whether express, implied, statutory, or otherwise, with respect to the App, including all implied warranties of
        merchantability, fitness for a particular purpose, title, and non-infringement.
      </Text>

      <Text variant="h2">7. Limitation of Liability</Text>
      <Text variant="body">
        To the fullest extent permitted by applicable law, in no event shall GVTech or its suppliers be liable for any
        special, incidental, indirect, or consequential damages whatsoever (including, but not limited to, damages for
        loss of profits, for loss of data or other information, for business interruption, for personal injury, for loss
        of privacy arising out of or in any way related to the use of or inability to use the App).
      </Text>

      <Text variant="h2">8. Governing Law</Text>
      <Text variant="body">
        The laws of the United States, excluding its conflicts of law rules, shall govern this Agreement and your use of
        the Application. Your use of the Application may also be subject to other local, state, national, or
        international laws.
      </Text>

      <Text variant="h2">9. Contact Information</Text>
      <Text variant="body">If you have any questions about these Terms, please contact us at:</Text>
      <Text variant="body">
        <strong>Email</strong>:{' '}
        <a href="mailto:parablebloom.support@garciaericn.com">parablebloom.support@garciaericn.com</a>
      </Text>
    </article>
  );
}
