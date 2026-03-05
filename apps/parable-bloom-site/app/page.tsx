import DesignSystemCard from "@/components/design-system-card";
import DesignSystemCta from "@/components/design-system-cta";

const cards = [
  {
    marker: "[WEB]",
    title: "Play on Web",
    body: "Play Parable Bloom instantly in your browser. No download required.",
  },
  {
    marker: "[ANDROID]",
    title: "Android",
    body: "Coming soon to Google Play. Stay tuned for the release.",
  },
  {
    marker: "[IOS]",
    title: "iOS",
    body: "Coming soon to the App Store. Stay tuned for the release.",
  },
];

export default function HomePage() {
  return (
    <>
      <section className="hero">
        <h1>Parable Bloom</h1>
        <p>
          A journey of mindfulness, puzzles, and faith. Guide vines through beautiful gardens, uncovering
          timeless parables in this zen puzzler.
        </p>
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
          <DesignSystemCard key={card.title} marker={card.marker} title={card.title} body={card.body} />
        ))}
      </section>
      <section className="page">
        <h2>Discover Peace in Puzzles</h2>
        <p>
          Parable Bloom is a moment of calm in a busy day. Immerse yourself in a world where logic meets
          spiritual reflection.
        </p>
        <p>
          Features include intuitive gameplay, organic visuals, meaningful narratives, and support for offline
          play.
        </p>
      </section>
    </>
  );
}
