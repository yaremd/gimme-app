// Run: deno test --node-modules-dir=none supabase/functions/identify-product/
import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  buildOffersUserText,
  makeTicketKey,
  type OffersTicket,
  pickOffers,
  readReportedOffers,
  type ReportedOffer,
  signTicket,
  verifyTicket,
} from "./offers.ts";

const NOW_SECONDS = 1_800_000_000;

const ticket: OffersTicket = {
  requestId: "6f1c1c9e-6c55-4c8e-9d0b-3f0f5d7a2b11",
  title: "Sony WH-1000XM6",
  brand: "Sony",
  model: "WH-1000XM6",
  searchQuery: "Sony WH-1000XM6 black",
  estimate: { low: 350, high: 400, currency: "USD" },
  expiresAt: NOW_SECONDS + 60,
};

Deno.test("a ticket round-trips and only the server's key opens it", async () => {
  const key = await makeTicketKey("secret-a");
  const token = await signTicket(key, ticket);
  assertEquals(await verifyTicket(key, token, NOW_SECONDS), ticket);
  assertEquals(await verifyTicket(await makeTicketKey("secret-b"), token, NOW_SECONDS), null);
  assertEquals(await verifyTicket(key, token, NOW_SECONDS + 60), null, "expired");
});

Deno.test("a ticket with any change to its payload is rejected", async () => {
  const key = await makeTicketKey("secret-a");
  const [payload, mac] = (await signTicket(key, ticket)).split(".");
  const tampered = btoa(JSON.stringify({ ...ticket, requestId: "someone-else" }))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  for (const token of [`${tampered}.${mac}`, `${payload}.`, `.${mac}`, `${payload}.${mac}.extra`, `${payload}.!!`]) {
    assertEquals(await verifyTicket(key, token, NOW_SECONDS), null, token);
  }
});

Deno.test("a ticket must carry every field", async () => {
  const key = await makeTicketKey("secret-a");
  const { searchQuery: _, ...missing } = ticket;
  const token = await signTicket(key, missing as unknown as OffersTicket);
  assertEquals(await verifyTicket(key, token, NOW_SECONDS), null);
});

Deno.test("the search request names the product, country and currency", () => {
  const text = buildOffersUserText(ticket, "US", "USD");
  for (const line of ["Product: Sony WH-1000XM6", "Brand: Sony", "Model: WH-1000XM6", "Shopping search: Sony WH-1000XM6 black", "User's country: US", "Prices in: USD", "Typical price new: 350–400 USD"]) {
    assert(text.includes(line), line);
  }
  const bare = buildOffersUserText({ ...ticket, brand: null, model: null, estimate: null }, null, "EUR");
  assert(!bare.includes("Brand:") && !bare.includes("Model:") && !bare.includes("country") && !bare.includes("Typical"));
});

Deno.test("reported offers keep only shops' product pages, one per shop", () => {
  const offers = readReportedOffers({
    offers: [
      { store: "  Sony  ", url: "https://electronics.sony.com/audio/headphones/p/wh1000xm6-b#reviews", price: 399.99, currency: "usd" },
      { store: "Sony again", url: "https://www.electronics.sony.com/other", price: 380, currency: "USD" },
      { store: "Best Buy", url: "https://www.bestbuy.com/site/sony-wh-1000xm6/6600000.p", price: "cheap", currency: "dollars" },
      { store: "Amazon search", url: "https://www.amazon.com/s?k=sony+wh-1000xm6", price: 349, currency: "USD" },
      { store: "eBay search", url: "https://www.ebay.com/sch/i.html?_nkw=xm6", price: 300, currency: "USD" },
      { store: "Google", url: "https://shopping.google.com/product/123", price: 1, currency: "USD" },
      { store: "YouTube", url: "https://youtu.be/abc", price: null, currency: null },
      { store: "Bad", url: "javascript:alert(1)", price: 1, currency: "USD" },
      { store: "Not a URL", url: "best buy", price: 1, currency: "USD" },
      { store: "", url: "https://www.crutchfield.com/p_158WH1XM6B/Sony-WH-1000XM6.html", price: 398, currency: "USD" },
    ],
  });
  assertEquals(offers, [
    { store: "Sony", url: "https://electronics.sony.com/audio/headphones/p/wh1000xm6-b", price: 399.99, currency: "USD" },
    { store: "Best Buy", url: "https://www.bestbuy.com/site/sony-wh-1000xm6/6600000.p", price: null, currency: null },
    { store: "crutchfield.com", url: "https://www.crutchfield.com/p_158WH1XM6B/Sony-WH-1000XM6.html", price: 398, currency: "USD" },
  ]);
});

Deno.test("a report that isn't a list of offers reads as nothing", () => {
  for (const input of [null, "offers", { offers: "none" }, [{ url: "https://a.com" }]]) {
    assertEquals(readReportedOffers(input), null);
  }
  assertEquals(readReportedOffers({ offers: [] }), []);
});

Deno.test("at most five reported offers are kept", () => {
  const offers = Array.from({ length: 8 }, (_, i) => ({
    store: `Shop ${i}`,
    url: `https://shop${i}.example/item`,
    price: 10 + i,
    currency: "USD",
  }));
  assertEquals(readReportedOffers({ offers })?.length, 5);
});

function reported(store: string, price: number | null = null, currency: string | null = null): ReportedOffer {
  return { store, url: `https://${store.toLowerCase()}.example/item`, price, currency };
}

Deno.test("offers are ranked by the price on their page", () => {
  const picked = pickOffers([
    { reported: reported("A", 300), page: { price: 389.5, currency: "USD", title: "A page" } },
    { reported: reported("B"), page: { price: 349.999, currency: "usd", title: null } },
    { reported: reported("C"), page: { price: 399, currency: "USD", title: "  C   page  " } },
    { reported: reported("D"), page: { price: 360, currency: "USD", title: "D" } },
  ], { currency: "USD", estimate: ticket.estimate, max: 3 });

  assertEquals(picked, [
    { store: "B", url: "https://b.example/item", title: null, price: 350, currency: "USD", best: true },
    { store: "D", url: "https://d.example/item", title: "D", price: 360, currency: "USD", best: false },
    { store: "A", url: "https://a.example/item", title: "A page", price: 389.5, currency: "USD", best: false },
  ]);
});

Deno.test("a page without a currency falls back to the one the search reported", () => {
  const picked = pickOffers([
    { reported: reported("A", 380, "USD"), page: { price: 379, currency: null, title: null } },
    { reported: reported("B", 380, null), page: { price: 370, currency: null, title: null } },
  ], { currency: "USD", estimate: null, max: 3 });
  assertEquals(picked.map((o) => o.store), ["A"]);
});

Deno.test("prices far outside the typical range are dropped", () => {
  const picked = pickOffers([
    { reported: reported("Case"), page: { price: 29, currency: "USD", title: "Case for XM6" } },
    { reported: reported("Bundle"), page: { price: 1200, currency: "USD", title: "XM6 bundle" } },
    { reported: reported("Real"), page: { price: 348, currency: "USD", title: "XM6" } },
  ], { currency: "USD", estimate: ticket.estimate, max: 3 });
  assertEquals(picked.map((o) => o.store), ["Real"]);

  // An estimate in another currency can't be compared, so nothing is dropped for it.
  const otherCurrency = pickOffers([
    { reported: reported("Case"), page: { price: 29, currency: "GBP", title: null } },
  ], { currency: "GBP", estimate: ticket.estimate, max: 3 });
  assertEquals(otherCurrency.length, 1);
});

Deno.test("offers with no confirmed price are dropped", () => {
  const picked = pickOffers([
    { reported: reported("Blocked", 300, "USD"), page: null },
    { reported: reported("NoPrice", 300, "USD"), page: { price: null, currency: "USD", title: "x" } },
    { reported: reported("Zero", 300, "USD"), page: { price: 0, currency: "USD", title: "x" } },
  ], { currency: "USD", estimate: null, max: 3 });
  assertEquals(picked, []);
});
