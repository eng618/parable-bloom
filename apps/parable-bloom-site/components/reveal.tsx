'use client';

import { useLayoutEffect, useRef, useState, type ElementType, type ReactNode } from 'react';

import { cn } from '@/lib/utils';

type RevealTag = 'div' | 'figure' | 'section' | 'article';

type RevealProps = {
  children: ReactNode;
  className?: string;
  /** Delay in milliseconds, used to stagger siblings. */
  delay?: number;
  as?: RevealTag;
};

/**
 * Fades a block up once, when it enters the viewport.
 * Content stays visible without JavaScript and when the reader prefers reduced motion.
 */
export default function Reveal({ children, className, delay = 0, as = 'div' }: RevealProps) {
  const ref = useRef<HTMLElement | null>(null);
  const [phase, setPhase] = useState<'idle' | 'hidden' | 'shown'>('idle');
  const Tag = as as ElementType;

  useLayoutEffect(() => {
    const node = ref.current;
    if (!node) return undefined;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return undefined;

    const rect = node.getBoundingClientRect();
    const inView = rect.top < window.innerHeight * 0.92 && rect.bottom > 0;

    if (inView) {
      setPhase('hidden');
      let inner = 0;
      const outer = requestAnimationFrame(() => {
        inner = requestAnimationFrame(() => setPhase('shown'));
      });
      return () => {
        cancelAnimationFrame(outer);
        cancelAnimationFrame(inner);
      };
    }

    setPhase('hidden');
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          setPhase('shown');
          observer.disconnect();
        }
      },
      { threshold: 0.18, rootMargin: '0px 0px -8% 0px' },
    );
    observer.observe(node);
    return () => observer.disconnect();
  }, []);

  return (
    <Tag
      ref={ref}
      className={cn(phase === 'hidden' && 'reveal-hidden', phase === 'shown' && 'reveal-shown', className)}
      style={phase === 'shown' ? { animationDelay: `${delay}ms` } : undefined}
    >
      {children}
    </Tag>
  );
}
