export default function Loading() {
  return (
    <div className="flex flex-col items-center gap-4 py-16" aria-busy="true" aria-label="Loading">
      <span className="animate-float text-5xl" role="img" aria-hidden="true">
        🌿
      </span>
      <div className="bg-brand/10 h-2 w-48 animate-pulse rounded-full" />
      <p className="text-text-secondary text-sm">Loading…</p>
    </div>
  );
}
