'use client';

export default function GlobalError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <html lang="en">
      <body>
        <div style={{ textAlign: 'center', padding: '4rem 1rem' }}>
          <h2>Something didn&apos;t bloom</h2>
          <p>An unexpected error occurred. Please reload.</p>
          <button type="button" onClick={reset}>
            Try again
          </button>
        </div>
      </body>
    </html>
  );
}
