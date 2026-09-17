'use client';

export default function Error({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div className="flex flex-col items-center gap-4 py-16 text-center">
      <span className="text-5xl" role="img" aria-hidden="true">
        🌱
      </span>
      <h2 className="font-display text-text-primary text-2xl font-semibold">Something didn&apos;t bloom</h2>
      <p className="text-text-secondary max-w-md text-sm">
        An unexpected error occurred. Please try again — your progress is safe.
      </p>
      <button
        type="button"
        onClick={reset}
        className="bg-brand hover:bg-brand/90 rounded-full px-6 py-2.5 text-sm font-semibold text-white transition-all hover:-translate-y-0.5"
      >
        Try again
      </button>
    </div>
  );
}
