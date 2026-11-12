import type { CSSProperties, ReactNode } from "react";
import { Icon } from "./brand";
import type { List, Screen, Wish } from "./data";

const cx = (...parts: Array<string | false | null | undefined>) => parts.filter(Boolean).join(" ");
const vars = (v: Record<string, string | number>) => v as CSSProperties;

/* ── Device frame ─────────────────────────────────────────────────────── */
export function Phone({
  screens,
  active = 0,
  className,
  style,
  eager,
}: {
  screens: Screen[];
  active?: number;
  className?: string;
  style?: CSSProperties;
  eager?: boolean;
}) {
  return (
    <div className={cx("g-phone", className)} style={style}>
      <div className="g-phone__bezel">
        <div className="g-phone__screen">
          {screens.map((s, i) => (
            <img
              key={s.src}
              src={s.src}
              alt={i === active ? s.alt : ""}
              aria-hidden={i === active ? undefined : true}
              data-active={i === active}
              width={804}
              height={1748}
              loading={eager && i === 0 ? "eager" : "lazy"}
              decoding="async"
              draggable={false}
            />
          ))}
          <span className="g-phone__island" aria-hidden="true" />
          <span className="g-phone__glare" aria-hidden="true" />
        </div>
      </div>
    </div>
  );
}

/* ── A wish's picture: a product photo, or an emoji on a tinted ground (lists) ── */
export function Tile({
  image,
  emoji,
  color = "#6C63FF",
  size,
}: {
  image?: string;
  emoji?: string;
  color?: string;
  size?: number;
}) {
  const style = vars({ "--c": color, ...(size ? { "--tile": `${size}px` } : {}) });
  if (image) {
    return (
      <span className="g-tile g-tile--photo" style={style} aria-hidden="true">
        <img src={image} alt="" width={400} height={400} loading="lazy" decoding="async" draggable={false} />
      </span>
    );
  }
  return (
    <span className="g-tile" style={style} aria-hidden="true">
      {emoji}
    </span>
  );
}

export function Badge({ kind, children }: { kind: "drop" | "gift" | "plain"; children: ReactNode }) {
  return (
    <span className={`g-badge g-badge--${kind}`}>
      {kind === "drop" && <Icon name="trend-down" style={{ width: 11, height: 11 }} />}
      {kind === "gift" && <Icon name="gift" style={{ width: 11, height: 11 }} />}
      {children}
    </span>
  );
}

/* ── Floating wish card ───────────────────────────────────────────────── */
export function WishCard({ wish, className, style }: { wish: Wish; className?: string; style?: CSSProperties }) {
  return (
    <div className={cx("g-wish g-glass", className)} style={style}>
      <Tile image={wish.image} />
      <span>
        <span className="g-wish__name">{wish.name}</span>
        <span className="g-wish__meta">
          {wish.price}
          {wish.badge && <Badge kind={wish.badge.kind}>{wish.badge.text}</Badge>}
        </span>
      </span>
    </div>
  );
}

/* ── List row, as on the Home screen ──────────────────────────────────── */
export function ListRow({ list, className, style }: { list: List; className?: string; style?: CSSProperties }) {
  return (
    <div className={cx("g-row", className)} style={{ ...vars({ "--c": list.color, "--p": `${list.progress}%` }), ...style }}>
      <span className="g-row__ico" aria-hidden="true">
        {list.emoji}
      </span>
      <span className="g-row__main">
        <span className="g-row__name">{list.name}</span>
        <span className="g-row__sub">{list.sub}</span>
      </span>
      <span className="g-row__side">
        <span className="g-row__val">{list.value}</span>
        <span className="g-row__bar" aria-hidden="true">
          <i />
        </span>
      </span>
    </div>
  );
}

/* ── Widgets, rebuilt from GimmeWidget/SmallWidgetView and MediumWidgetView ── */
function Ring({ fraction, label, size = 48 }: { fraction: number; label: string; size?: number }) {
  return (
    <span className="g-ring" style={{ width: size, height: size }}>
      <svg viewBox="0 0 48 48" aria-hidden="true">
        <circle className="g-ring__track" cx="24" cy="24" r="21.5" />
        <circle className="g-ring__val" cx="24" cy="24" r="21.5" pathLength={1} style={vars({ "--f": fraction })} />
      </svg>
      <b>{label}</b>
    </span>
  );
}

function WidgetSummary({ ringSize }: { ringSize: number }) {
  return (
    <span className="g-widget__col">
      <span className="g-widget__head">
        <span className="g-emoji">🎂</span>
        Birthday
        <span className="g-widget__plus">
          <Icon name="plus" style={{ strokeWidth: 3 }} />
        </span>
      </span>
      <span className="g-widget__mid">
        <Ring fraction={0.17} label="17%" size={ringSize} />
        <span>
          <span className="g-widget__value">$673</span>
          <span className="g-widget__done">1/6 done</span>
        </span>
      </span>
      <span className="g-widget__foot">
        <Icon name="clock" style={{ strokeWidth: 2.6 }} />
        23d left
      </span>
    </span>
  );
}

export function WidgetSmall({ className, style }: { className?: string; style?: CSSProperties }) {
  return (
    <div className={cx("g-widget", className)} style={style} role="img" aria-label="Small Gimme widget: Birthday list, 17 percent done, $673 left, 23 days to go">
      <WidgetSummary ringSize={48} />
    </div>
  );
}

export function WidgetMedium({ className, style }: { className?: string; style?: CSSProperties }) {
  // the real widget shows each wish with its list's emoji (WidgetDataService.swift)
  const items = [
    { emoji: "🎂", name: "Nike Free running shoes", price: "$99" },
    { emoji: "🎂", name: "Sony wireless headphones", price: "$349" },
    { emoji: "🎂", name: "Polaroid Supercolor 1000", price: "$119" },
  ];
  return (
    <div className={cx("g-widget g-widget--medium", className)} style={style} role="img" aria-label="Medium Gimme widget: Birthday list summary with its top three wishes">
      <WidgetSummary ringSize={44} />
      <span className="g-widget__sep" />
      <span className="g-widget__items">
        {items.map((it) => (
          <span className="g-widget__item" key={it.name}>
            <span className="g-emoji">{it.emoji}</span>
            <span style={{ minWidth: 0 }}>
              <b>{it.name}</b>
              <small>{it.price}</small>
            </span>
          </span>
        ))}
      </span>
    </div>
  );
}

/* ── Spotlight and Siri ───────────────────────────────────────────────── */
export function Spotlight({ query = "nike", className }: { query?: string; className?: string }) {
  return (
    <div className={cx("g-spot g-ui", className)} role="img" aria-label={`Spotlight search for ${query} finds Nike Free running shoes in Gimme`}>
      <div className="g-spot__bar g-glass">
        <Icon name="search" />
        <span>{query}</span>
        <span className="g-spot__caret" />
      </div>
      <div className="g-spot__hit">
        <Tile image="/v2/products/shoes.webp" size={38} />
        <span>
          <b>Nike Free running shoes</b>
          <small>Birthday · $99</small>
        </span>
        <img src="/v2/icon-dark.png" alt="" width={22} height={22} />
      </div>
    </div>
  );
}

export function SiriPhrase({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cx("g-siri", className)}>{children}</div>;
}

/* ── Rich link preview, as a shared list arrives in Messages ──────────── */
export function LinkPreview({ className, style }: { className?: string; style?: CSSProperties }) {
  return (
    <div className={cx("g-link g-glass", className)} style={style}>
      <div className="g-link__preview">
        <span className="g-tile" style={vars({ "--c": "#E8586D", "--tile": "44px" })}>
          🎂
        </span>
        <span>
          <span className="g-link__title">Birthday · 6 wishes</span>
          <span className="g-link__host">gimmelist.com</span>
        </span>
      </div>
    </div>
  );
}

/* ── QR code to the App Store, for people reading on a computer ───────── */
export function QRCard({ className }: { className?: string }) {
  return (
    <div className={cx("g-qr g-glass", className)}>
      <img src="/v2/qr.svg" alt="QR code that opens Gimme on the App Store" width={74} height={74} />
      <span>
        <b>On a computer?</b>
        Scan to get Gimme
        <br />
        on your iPhone.
      </span>
    </div>
  );
}
