import { HandRing, Sparkle, Wordmark } from "../../_site/brand";
import { SCREENS, WISHES } from "../../_site/data";
import { Phone, WishCard } from "../../_site/fragments";
import "./og.css";

/* The social preview card (public/og.jpg) is a 1200×630 screenshot of this page.
   To re-render it after a design change, open /options/og locally at exactly that
   size, capture it, save it over public/og.jpg and bump the version in
   _site/meta.ts. Like the rest of /options this route is not on the live site. */
export default function OgCard() {
  return (
    <div className="og" data-inview="true">
      <div className="g-sky" />
      <div className="og__halo" />
      <div className="og__copy">
        <Wordmark className="og__logo" />
        <p className="og__title">
          Wish it.
          <br />
          Share it.
          <br />
          <span className="g-ringed">
            Get it.
            <HandRing />
            <Sparkle still className="og__spark" />
          </span>
        </p>
        <p className="og__sub">The wishlist app for iPhone. Friends claim gifts from one link.</p>
      </div>
      <div className="og__stage">
        <Phone screens={[SCREENS.homeDark]} eager className="og__phone" />
        <WishCard wish={WISHES[0]} className="og__card og__card--1" />
        <WishCard wish={WISHES[1]} className="og__card og__card--2" />
        <WishCard wish={WISHES[2]} className="og__card og__card--3" />
      </div>
    </div>
  );
}
