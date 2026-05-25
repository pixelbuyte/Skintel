import {
  useEffect,
  useRef,
  useState,
  type ReactNode,
  type CSSProperties,
  type MouseEvent as ReactMouseEvent,
  type ButtonHTMLAttributes,
} from 'react';

type TiltProps = {
  children: ReactNode;
  className?: string;
  max?: number;
  lift?: number;
  shine?: boolean;
  disabled?: boolean;
  style?: CSSProperties;
};

export function Tilt3D({
  children,
  className = '',
  max = 10,
  lift = 14,
  shine = true,
  disabled = false,
  style,
}: TiltProps) {
  const ref = useRef<HTMLDivElement>(null);
  const [tx, setTx] = useState(0);
  const [ty, setTy] = useState(0);
  const [hovered, setHovered] = useState(false);
  const [shinePos, setShinePos] = useState({ x: 50, y: 50 });
  const [reducedMotion, setReducedMotion] = useState(false);

  useEffect(() => {
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    setReducedMotion(mq.matches);
    const onChange = () => setReducedMotion(mq.matches);
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);

  const active = !disabled && !reducedMotion;

  function onMove(e: ReactMouseEvent<HTMLDivElement>) {
    if (!active || !ref.current) return;
    const rect = ref.current.getBoundingClientRect();
    const px = (e.clientX - rect.left) / rect.width;
    const py = (e.clientY - rect.top) / rect.height;
    const nx = (px - 0.5) * 2;
    const ny = (py - 0.5) * 2;
    setTx(ny * -max);
    setTy(nx * max);
    setShinePos({ x: px * 100, y: py * 100 });
  }

  function reset() {
    setHovered(false);
    setTx(0);
    setTy(0);
    setShinePos({ x: 50, y: 50 });
  }

  return (
    <div
      ref={ref}
      onMouseEnter={() => setHovered(true)}
      onMouseMove={onMove}
      onMouseLeave={reset}
      className={`relative ${className}`}
      style={{
        perspective: '1200px',
        transformStyle: 'preserve-3d',
        ...style,
      }}
    >
      <div
        className="relative h-full will-change-transform"
        style={{
          transformStyle: 'preserve-3d',
          transform: active
            ? `rotateX(${tx}deg) rotateY(${ty}deg) translateZ(${hovered ? lift : 0}px)`
            : 'none',
          transition: hovered
            ? 'transform 120ms cubic-bezier(0.22,1,0.36,1)'
            : 'transform 500ms cubic-bezier(0.22,1,0.36,1)',
        }}
      >
        {children}
        {shine && active && hovered && (
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 rounded-[inherit] opacity-70 transition-opacity duration-200"
            style={{
              background: `radial-gradient(420px circle at ${shinePos.x}% ${shinePos.y}%, rgba(255,255,255,0.22), transparent 45%)`,
              mixBlendMode: 'overlay',
            }}
          />
        )}
      </div>
    </div>
  );
}

type FlipProps = {
  front: ReactNode;
  back: ReactNode;
  className?: string;
  flipped?: boolean;
  onToggle?: () => void;
};

export function Flip3D({ front, back, className = '', flipped, onToggle }: FlipProps) {
  const [internal, setInternal] = useState(false);
  const isFlipped = flipped ?? internal;
  const toggle = () => {
    if (onToggle) onToggle();
    else setInternal((v) => !v);
  };
  return (
    <div
      className={`relative ${className}`}
      style={{ perspective: '1400px' }}
      onClick={toggle}
      role="button"
      tabIndex={0}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          toggle();
        }
      }}
    >
      <div
        className="relative w-full h-full transition-transform duration-700 ease-emil"
        style={{
          transformStyle: 'preserve-3d',
          transform: isFlipped ? 'rotateY(180deg)' : 'rotateY(0deg)',
        }}
      >
        <div
          className="w-full"
          style={{ backfaceVisibility: 'hidden', WebkitBackfaceVisibility: 'hidden' }}
        >
          {front}
        </div>
        <div
          className="absolute inset-0 w-full"
          style={{
            backfaceVisibility: 'hidden',
            WebkitBackfaceVisibility: 'hidden',
            transform: 'rotateY(180deg)',
          }}
        >
          {back}
        </div>
      </div>
    </div>
  );
}

/** Conic-gradient rotating border. Wraps children + glows around them. */
export function AnimatedBorder({
  children,
  className = '',
  active = true,
  intensity = 1,
}: {
  children: ReactNode;
  className?: string;
  active?: boolean;
  intensity?: number;
}) {
  return (
    <div className={`relative ${className}`}>
      {active && (
        <div
          aria-hidden
          className="pointer-events-none absolute -inset-px rounded-[inherit] opacity-90"
          style={{
            background:
              'conic-gradient(from var(--angle, 0deg), rgba(163,88,72,0) 0%, rgba(163,88,72,0.45) 25%, rgba(255,200,180,0.7) 35%, rgba(163,88,72,0.45) 45%, rgba(163,88,72,0) 70%, rgba(163,88,72,0) 100%)',
            animation: `borderSpin ${6 / intensity}s linear infinite`,
            filter: 'blur(6px)',
            zIndex: 0,
          }}
        />
      )}
      <div className="relative" style={{ zIndex: 1 }}>
        {children}
      </div>
      <style>{`
        @property --angle {
          syntax: '<angle>';
          initial-value: 0deg;
          inherits: false;
        }
        @keyframes borderSpin {
          to { --angle: 360deg; }
        }
      `}</style>
    </div>
  );
}

/** Floating sparkle field — randomly placed dots that drift + twinkle. */
export function SparkleField({
  count = 14,
  className = '',
}: {
  count?: number;
  className?: string;
}) {
  const sparkles = useRef<{ x: number; y: number; size: number; delay: number; dur: number }[]>(
    [],
  );
  if (sparkles.current.length === 0) {
    for (let i = 0; i < count; i++) {
      sparkles.current.push({
        x: Math.random() * 100,
        y: Math.random() * 100,
        size: 1 + Math.random() * 2,
        delay: Math.random() * 4,
        dur: 2.5 + Math.random() * 3,
      });
    }
  }
  return (
    <div className={`pointer-events-none absolute inset-0 overflow-hidden ${className}`} aria-hidden>
      {sparkles.current.map((s, i) => (
        <span
          key={i}
          className="absolute rounded-full bg-primary"
          style={{
            left: `${s.x}%`,
            top: `${s.y}%`,
            width: `${s.size}px`,
            height: `${s.size}px`,
            animation: `sparkleFloat ${s.dur}s ease-in-out ${s.delay}s infinite, sparkleTwinkle ${s.dur}s ease-in-out ${s.delay}s infinite`,
            filter: 'blur(0.5px)',
            boxShadow: '0 0 6px rgba(163,88,72,0.6)',
          }}
        />
      ))}
      <style>{`
        @keyframes sparkleFloat {
          0%, 100% { transform: translateY(0) translateX(0); }
          50% { transform: translateY(-14px) translateX(6px); }
        }
        @keyframes sparkleTwinkle {
          0%, 100% { opacity: 0.2; }
          50% { opacity: 1; }
        }
      `}</style>
    </div>
  );
}

/** Magnetic button — drifts toward cursor on hover. Builds a click ripple effect too. */
export function MagneticButton({
  children,
  strength = 0.35,
  className = '',
  onClick,
  ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  children: ReactNode;
  strength?: number;
  className?: string;
}) {
  const ref = useRef<HTMLButtonElement>(null);
  const [pos, setPos] = useState({ x: 0, y: 0 });
  const [ripples, setRipples] = useState<{ id: number; x: number; y: number }[]>([]);
  const [reducedMotion, setReducedMotion] = useState(false);

  useEffect(() => {
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    setReducedMotion(mq.matches);
    const onChange = () => setReducedMotion(mq.matches);
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);

  function onMove(e: ReactMouseEvent<HTMLButtonElement>) {
    if (reducedMotion || !ref.current) return;
    const rect = ref.current.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    setPos({ x: (e.clientX - cx) * strength, y: (e.clientY - cy) * strength });
  }

  function onClickInternal(e: ReactMouseEvent<HTMLButtonElement>) {
    if (ref.current) {
      const rect = ref.current.getBoundingClientRect();
      const id = Date.now();
      setRipples((r) => [...r, { id, x: e.clientX - rect.left, y: e.clientY - rect.top }]);
      window.setTimeout(() => {
        setRipples((r) => r.filter((p) => p.id !== id));
      }, 700);
    }
    onClick?.(e);
  }

  return (
    <button
      ref={ref}
      onMouseMove={onMove}
      onMouseLeave={() => setPos({ x: 0, y: 0 })}
      onClick={onClickInternal}
      className={`relative overflow-hidden ${className}`}
      style={{
        transform: `translate(${pos.x}px, ${pos.y}px)`,
        transition: 'transform 200ms cubic-bezier(0.22,1,0.36,1)',
      }}
      {...rest}
    >
      <span className="relative z-10 inline-flex items-center justify-center gap-2">{children}</span>
      {ripples.map((r) => (
        <span
          key={r.id}
          aria-hidden
          className="pointer-events-none absolute rounded-full bg-white/40"
          style={{
            left: r.x,
            top: r.y,
            width: 8,
            height: 8,
            transform: 'translate(-50%, -50%)',
            animation: 'rippleExpand 650ms cubic-bezier(0.22,1,0.36,1) forwards',
          }}
        />
      ))}
      <style>{`
        @keyframes rippleExpand {
          0% { transform: translate(-50%, -50%) scale(1); opacity: 0.6; }
          100% { transform: translate(-50%, -50%) scale(40); opacity: 0; }
        }
      `}</style>
    </button>
  );
}

/** Count-up animation. Re-runs whenever `to` changes. */
export function CountUp({
  to,
  prefix = '',
  suffix = '',
  duration = 1100,
  className = '',
}: {
  to: number;
  prefix?: string;
  suffix?: string;
  duration?: number;
  className?: string;
}) {
  const [val, setVal] = useState(0);
  const ref = useRef<HTMLSpanElement>(null);
  const started = useRef(false);

  useEffect(() => {
    started.current = false;
    setVal(0);
    if (!ref.current) return;
    const io = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting && !started.current) {
          started.current = true;
          const start = performance.now();
          const tick = (now: number) => {
            const t = Math.min(1, (now - start) / duration);
            const eased = 1 - Math.pow(1 - t, 3);
            setVal(Math.round(to * eased));
            if (t < 1) requestAnimationFrame(tick);
          };
          requestAnimationFrame(tick);
        }
      },
      { threshold: 0.3 },
    );
    io.observe(ref.current);
    return () => io.disconnect();
  }, [to, duration]);

  return (
    <span ref={ref} className={className}>
      {prefix}
      {val}
      {suffix}
    </span>
  );
}
