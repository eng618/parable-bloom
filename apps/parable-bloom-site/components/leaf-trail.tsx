'use client';

import { useEffect, useRef } from 'react';

const POOL = 12;
const MIN_GAP_MS = 48;
const MIN_DIST = 18;
const LIFE_MS = 1100;
const SVG_NS = 'http://www.w3.org/2000/svg';

type Spec = {
  x: number;
  y: number;
  vx: number;
  vy: number;
  rot: number;
  vr: number;
  born: number;
  life: number;
  size: number;
  active: boolean;
};

function createLeafSvg(index: number) {
  const svg = document.createElementNS(SVG_NS, 'svg');
  svg.setAttribute('width', '22');
  svg.setAttribute('height', '16');
  svg.setAttribute('viewBox', '0 0 22 16');
  svg.setAttribute('fill', 'none');
  svg.setAttribute('aria-hidden', 'true');

  const leaf = document.createElementNS(SVG_NS, 'path');
  leaf.setAttribute(
    'd',
    'M2.2 9.2C5.4 8 8 5.2 9.2 1.6c1.4 3.4 4.6 6.2 10.2 7.4-3.6 1.2-6.2 3.6-7.6 6.2C10.2 12.4 6.6 10.4 2.2 9.2Z',
  );
  leaf.setAttribute('fill', index % 2 === 0 ? '#8da082' : '#4d6844');

  const vein = document.createElementNS(SVG_NS, 'path');
  vein.setAttribute('d', 'M9.2 2.2c.3 3.4.2 5.8-.2 8.4');
  vein.setAttribute('stroke', '#fffbf3');
  vein.setAttribute('stroke-opacity', '0.55');
  vein.setAttribute('stroke-width', '0.7');

  svg.append(leaf, vein);
  return svg;
}

/**
 * A short trail of garden leaves behind a fine pointer.
 * Stays off for touch and for readers who prefer reduced motion.
 */
export default function LeafTrail() {
  const frame = useRef(0);

  useEffect(() => {
    const fine = window.matchMedia('(hover: hover) and (pointer: fine)').matches;
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (!fine || reduce) return undefined;

    const host = document.createElement('div');
    host.setAttribute('aria-hidden', 'true');
    host.className = 'pointer-events-none fixed inset-0 z-30 overflow-hidden';

    const nodes: HTMLSpanElement[] = [];
    for (let index = 0; index < POOL; index += 1) {
      const span = document.createElement('span');
      span.className = 'absolute top-0 left-0 opacity-0 will-change-transform';
      span.append(createLeafSvg(index));
      host.append(span);
      nodes.push(span);
    }
    document.body.append(host);

    const specs: Spec[] = Array.from({ length: POOL }, () => ({
      x: 0,
      y: 0,
      vx: 0,
      vy: 0,
      rot: 0,
      vr: 0,
      born: 0,
      life: LIFE_MS,
      size: 1,
      active: false,
    }));
    let cursor = 0;
    const last = { x: 0, y: 0, t: 0 };

    const tick = (now: number) => {
      let alive = false;
      for (let index = 0; index < POOL; index += 1) {
        const spec = specs[index];
        const node = nodes[index];
        if (!spec?.active || !node) continue;
        const progress = (now - spec.born) / spec.life;
        if (progress >= 1) {
          spec.active = false;
          node.style.opacity = '0';
          continue;
        }
        alive = true;
        const fade = progress < 0.12 ? progress / 0.12 : 1 - (progress - 0.12) / 0.88;
        const x = spec.x + spec.vx * progress - 11 * spec.size;
        const y = spec.y + spec.vy * progress + 12 * progress * progress - 8 * spec.size;
        const rot = spec.rot + spec.vr * progress;
        node.style.opacity = String(Math.max(0, fade) * 0.78);
        node.style.transform = `translate3d(${x}px, ${y}px, 0) rotate(${rot}deg) scale(${spec.size})`;
      }
      frame.current = alive ? requestAnimationFrame(tick) : 0;
    };

    const kick = () => {
      if (frame.current === 0) frame.current = requestAnimationFrame(tick);
    };

    const spawn = (x: number, y: number, dx: number, dy: number) => {
      const index = cursor;
      cursor = (cursor + 1) % POOL;
      const spec = specs[index];
      if (!spec) return;
      const angle = Math.atan2(dy, dx);
      spec.x = x;
      spec.y = y;
      spec.vx = Math.cos(angle) * 8 + (Math.random() - 0.5) * 12;
      spec.vy = 14 + Math.random() * 16;
      spec.rot = (Math.random() - 0.5) * 36;
      spec.vr = (Math.random() - 0.5) * 64;
      spec.born = performance.now();
      spec.life = LIFE_MS + Math.random() * 360;
      spec.size = 0.72 + Math.random() * 0.4;
      spec.active = true;
      kick();
    };

    const onMove = (event: PointerEvent) => {
      if (event.pointerType !== 'mouse' || document.hidden) return;
      const now = performance.now();
      const dx = event.clientX - last.x;
      const dy = event.clientY - last.y;
      if (now - last.t < MIN_GAP_MS && Math.hypot(dx, dy) < MIN_DIST) return;
      last.x = event.clientX;
      last.y = event.clientY;
      last.t = now;
      spawn(event.clientX, event.clientY, dx, dy);
    };

    const onVisibility = () => {
      if (!document.hidden) return;
      if (frame.current !== 0) cancelAnimationFrame(frame.current);
      frame.current = 0;
      for (const spec of specs) spec.active = false;
      for (const node of nodes) node.style.opacity = '0';
    };

    window.addEventListener('pointermove', onMove, { passive: true });
    document.addEventListener('visibilitychange', onVisibility);

    return () => {
      window.removeEventListener('pointermove', onMove);
      document.removeEventListener('visibilitychange', onVisibility);
      if (frame.current !== 0) cancelAnimationFrame(frame.current);
      frame.current = 0;
      host.remove();
    };
  }, []);

  return null;
}
