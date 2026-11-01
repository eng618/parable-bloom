import Image from 'next/image';
import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="flex flex-col items-center gap-4 py-16 text-center">
      <Image src="/art/leaf_sprig.png" alt="" width={72} height={44} className="opacity-90" aria-hidden="true" />
      <h2 className="font-display text-brand text-2xl font-semibold">Path not found</h2>
      <p className="text-text-secondary max-w-md text-sm">
        This garden path doesn&apos;t exist. Let&apos;s guide you back.
      </p>
      <Link href="/" className="cta-primary">
        Back home
      </Link>
    </div>
  );
}
