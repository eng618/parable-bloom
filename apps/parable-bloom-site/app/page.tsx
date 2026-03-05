import type { Metadata } from "next";
import DesignSystemCard from "@/components/design-system-card";
import DesignSystemCta from "@/components/design-system-cta";
import { Text } from "@gv-tech/ui-web";

export const metadata: Metadata = {
  title: "Parable Bloom",
  description: "A zen hyper-casual arrow puzzle game with faith-based themes.",
};

const cards = [
  {
    marker: "🌐",
    title: "Play on Web",
    body: "Play Parable Bloom instantly in your browser. No download required.",
    href: "https://parable-bloom.web.app/",
    ctaLabel: "Play"
  },
  {
    marker: "📱",
    title: "Android",
    body: "Get it on Google Play.",
    href: "https://play.google.com/store/apps/details?id=com.eng618.parablebloom",
    ctaLabel: "Get on Google Play"
  },
  {
    marker: "🍏",
    title: "iOS",
    body: "Download on the App Store.",
    href: "https://apps.apple.com/app/parable-bloom/id1234567890",
    ctaLabel: "Download on App Store"
  },
];

export default function HomePage() {
  return (
    <>
      <section className="hero">
        <Text variant="h1">Parable Bloom</Text>
        <Text variant="body">A journey of mindfulness, puzzles, and faith. Guide vines through beautiful gardens, uncovering timeless parables in this zen puzzler.</Text>
        <div className="actions">
          <DesignSystemCta href="https://play.google.com/store/apps/details?id=com.eng618.parablebloom">
            Get it on Google Play
          </DesignSystemCta>
          <DesignSystemCta href="https://apps.apple.com/app/parable-bloom/id1234567890" variant="secondary">
            Download on App Store
          </DesignSystemCta>
        </div>
      </section>
      <section className="card-grid" aria-label="Platform availability">
        {cards.map((card) => (
          <DesignSystemCard key={card.title} marker={card.marker} title={card.title} body={card.body} href={card.href} ctaLabel={card.ctaLabel} />
        ))}
      </section>
      <section className="page">
        <Text variant="h2">Discover Peace in Puzzles</Text>
        <Text variant="body">
          Parable Bloom isn't just a game; it's a moment of calm in your busy day. Immerse yourself in a world where logic meets spiritual reflection.
        </Text>
        <Text variant="body">
          <strong>Features:</strong>
        </Text>
        <ul>
          <li><Text variant="body">Intuitive Gameplay: Simple swipe controls to guide the vines.</Text></li>
          <li><Text variant="body">Beautiful Aesthetics: lush, organic visuals that evolve as you play.</Text></li>
          <li><Text variant="body">Meaningful Narratives: Unlock faith-inspired stories and parables.</Text></li>
          <li><Text variant="body">Offline Play: enjoy the serenity anywhere, anytime.</Text></li>
        </ul>
      </section>
    </>
  );
}
