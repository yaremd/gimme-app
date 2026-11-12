import type { Metadata } from "next";
import { Figtree, Gabarito, Geist, Geist_Mono, Nunito, Unbounded } from "next/font/google";
import { OptionSwitcher } from "./_shared/live";
import "./v2.css";

/* Landing-page design options for the redesign. Temporary: once one is chosen it
   moves to "/" and this folder goes away. Kept out of search engines meanwhile. */

const figtree = Figtree({ subsets: ["latin"], display: "swap", variable: "--font-figtree" });
const gabarito = Gabarito({ subsets: ["latin"], display: "swap", variable: "--font-gabarito", preload: false });
const geistMono = Geist_Mono({ subsets: ["latin"], display: "swap", variable: "--font-geist-mono", preload: false });
const nunito = Nunito({ subsets: ["latin"], display: "swap", variable: "--font-nunito", preload: false });
const unbounded = Unbounded({ subsets: ["latin"], display: "swap", variable: "--font-unbounded", preload: false });
const geist = Geist({ subsets: ["latin"], display: "swap", variable: "--font-geist", preload: false });

export const metadata: Metadata = {
  title: "Gimme landing options",
  robots: { index: false, follow: false },
};

export default function V2Layout({ children }: { children: React.ReactNode }) {
  const fonts = [figtree, gabarito, geistMono, nunito, unbounded, geist].map((f) => f.variable).join(" ");
  return (
    <div className={`g-root ${fonts}`}>
      {/* Reveal states only hide content once scripting is known to work. */}
      <script dangerouslySetInnerHTML={{ __html: "document.documentElement.classList.add('js')" }} />
      {children}
      <OptionSwitcher />
    </div>
  );
}
