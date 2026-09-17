import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="flex flex-col items-center gap-4 py-16 text-center">
      <span className="text-5xl" role="img" aria-hidden="true">
        🍂
      </span>
      <h2 className="font-display text-text-primary text-2xl font-semibold">Path not found</h2>
      <p className="text-text-secondary max-w-md text-sm">
        This garden path doesn&apos;t exist. Let&apos;s guide you back.
      </p>
      <Link
        href="/"
        className="bg-brand hover:bg-brand/90 rounded-full px-6 py-2.5 text-sm font-semibold text-white transition-all hover:-translate-y-0.5"
      >
        Back home
      </Link>
    </div>
  );
}
