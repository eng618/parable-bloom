import Image from 'next/image';

import { cn } from '@/lib/utils';

type PhoneShotProps = {
  src: string;
  alt: string;
  /** CSS object-position, so each screen keeps its subject inside the shared window. */
  objectPosition?: string;
  priority?: boolean;
  sizes?: string;
  float?: boolean;
  className?: string;
};

export default function PhoneShot({
  src,
  alt,
  objectPosition = 'center',
  priority = false,
  sizes = '(min-width: 768px) 22vw, 45vw',
  float = false,
  className,
}: PhoneShotProps) {
  return (
    <div className={cn('phone-shot', float && 'animate-float', className)}>
      <div className="phone-shot-screen">
        <Image
          src={src}
          alt={alt}
          fill
          priority={priority}
          sizes={sizes}
          className="object-cover"
          style={{ objectPosition }}
        />
      </div>
    </div>
  );
}
