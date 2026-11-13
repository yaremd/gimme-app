import type { Metadata } from "next";
import { Geist, Unbounded } from "next/font/google";
import { notFound } from "next/navigation";
import { OptionSwitcher } from "../_site/live";

/* The two landing-page designs that were not chosen (B and C), kept for later.
   They are a local preview only: on the live site every /options URL is a 404. */

const unbounded = Unbounded({ subsets: ["latin"], display: "swap", variable: "--font-unbounded", preload: false });
const geist = Geist({ subsets: ["latin"], display: "swap", variable: "--font-geist", preload: false });

export const metadata: Metadata = {
  title: "Gimme landing options",
  robots: { index: false, follow: false },
};

export default function OptionsLayout({ children }: { children: React.ReactNode }) {
  if (process.env.NODE_ENV === "production") notFound();
  return (
    <div className={`${unbounded.variable} ${geist.variable}`}>
      {children}
      <OptionSwitcher />
    </div>
  );
}
