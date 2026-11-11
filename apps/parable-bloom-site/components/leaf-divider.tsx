import Image from 'next/image';

import { cn } from '@/lib/utils';

type LeafDividerProps = {
  className?: string;
};

export default function LeafDivider({ className }: LeafDividerProps) {
  return (
    <div className={cn('leaf-divider', className)} aria-hidden="true">
      <Image src="/art/leaf_pair.png" alt="" width={72} height={24} className="opacity-90" />
    </div>
  );
}
