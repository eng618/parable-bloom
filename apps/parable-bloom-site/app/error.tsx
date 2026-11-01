'use client';

export default function Error({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div className="flex flex-col items-center gap-4 py-16 text-center">
      <h2 className="font-display text-brand text-2xl font-semibold">Something didn&apos;t bloom</h2>
      <p className="text-text-secondary max-w-md text-sm">
        An unexpected error occurred. Please try again — your progress is safe.
      </p>
      <button type="button" onClick={reset} className="cta-primary">
        Try again
      </button>
    </div>
  );
}
