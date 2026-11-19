// Run: deno test --node-modules-dir=none supabase/functions/identify-product/
import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  buildOffersUserText,
  describeOffersSearch,
  makeTicketKey,
  type OffersTicket,
  pickOffers,
  readReportedOffers,
  type ReportedOffer,
  reportedCount,
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
  assert(!text.includes("Exact product") && !bare.includes("Exact product"));
});

Deno.test("a close match asks for the closest item, and its ticket says so", async () => {
  const closeMatch: OffersTicket = {
    ...ticket,
    title: "Grey wool beanie with leather patch",
    brand: null,
    model: null,
    searchQuery: "grey wool beanie leather patch",
    similar: true,
  };
  assert(buildOffersUserText(closeMatch, "US", "USD").includes(
    "Exact product: unknown. The photo shows an item like this, so find the closest match.",
  ));
  const key = await makeTicketKey("secret-a");
  assertEquals(await verifyTicket(key, await signTicket(key, closeMatch), NOW_SECONDS), closeMatch);
  const badFlag = await signTicket(key, { ...closeMatch, similar: "yes" } as unknown as OffersTicket);
  assertEquals(await verifyTicket(key, badFlag, NOW_SECONDS), null);
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
  const { offers, drops } = pickOffers([
    { reported: reported("A", 300), page: { price: 389.5, currency: "USD", title: "A page" } },
    { reported: reported("B"), page: { price: 349.999, currency: "usd", title: null } },
    { reported: reported("C"), page: { price: 399, currency: "USD", title: "  C   page  " } },
    { reported: reported("D"), page: { price: 360, currency: "USD", title: "D" } },
  ], { currency: "USD", estimate: ticket.estimate, max: 3 });

  assertEquals(offers, [
    { store: "B", url: "https://b.example/item", title: null, price: 350, currency: "USD", checked: true, best: true },
    { store: "D", url: "https://d.example/item", title: "D", price: 360, currency: "USD", checked: true, best: false },
    { store: "A", url: "https://a.example/item", title: "A page", price: 389.5, currency: "USD", checked: true, best: false },
  ]);
  assertEquals(drops, {
    unreadable: 0,
    unreadableDomains: [],
    noPrice: 0,
    noPriceDomains: [],
    otherCurrency: {},
    outOfRange: 0,
  });
});

Deno.test("a page without a currency falls back to the one the search reported", () => {
  const { offers, drops } = pickOffers([
    { reported: reported("A", 380, "USD"), page: { price: 379, currency: null, title: null } },
    { reported: reported("B", 380, null), page: { price: 370, currency: null, title: null } },
  ], { currency: "USD", estimate: null, max: 3 });
  assertEquals(offers.map((o) => o.store), ["A"]);
  assertEquals(drops.otherCurrency, { none: 1 });
});

Deno.test("prices far outside the typical range are dropped", () => {
  const { offers, drops } = pickOffers([
    { reported: reported("Case"), page: { price: 29, currency: "USD", title: "Case for XM6" } },
    { reported: reported("Bundle"), page: { price: 1200, currency: "USD", title: "XM6 bundle" } },
    { reported: reported("Real"), page: { price: 348, currency: "USD", title: "XM6" } },
  ], { currency: "USD", estimate: ticket.estimate, max: 3 });
  assertEquals(offers.map((o) => o.store), ["Real"]);
  assertEquals(drops.outOfRange, 2);

  // An estimate in another currency can't be compared, so nothing is dropped for it.
  const otherCurrency = pickOffers([
    { reported: reported("Case"), page: { price: 29, currency: "GBP", title: null } },
  ], { currency: "GBP", estimate: ticket.estimate, max: 3 });
  assertEquals(otherCurrency.offers.length, 1);
});

Deno.test("a page that can't be checked keeps the price the search reported", () => {
  const input = [
    { reported: reported("Zero", 310, "USD"), page: { price: 0, currency: "USD", title: null } },
    { reported: reported("Blocked", 299.999, "USD"), page: null },
    { reported: reported("NoPrice", 300, "USD"), page: { price: null, currency: "USD", title: "  No   price  " } },
    { reported: reported("Checked"), page: { price: 389, currency: "USD", title: null } },
  ];
  const { offers, drops } = pickOffers(input, { currency: "USD", estimate: ticket.estimate, max: 5 });
  // Checked prices first, even when a search price is lower, then search prices, cheapest first.
  assertEquals(offers, [
    { store: "Checked", url: "https://checked.example/item", title: null, price: 389, currency: "USD", checked: true, best: true },
    { store: "Blocked", url: "https://blocked.example/item", title: null, price: 300, currency: "USD", checked: false, best: false },
    { store: "NoPrice", url: "https://noprice.example/item", title: "No price", price: 300, currency: "USD", checked: false, best: false },
    { store: "Zero", url: "https://zero.example/item", title: null, price: 310, currency: "USD", checked: false, best: false },
  ]);
  // Every page that couldn't be checked is still counted. Domains only, so the link
  // reader can be improved for those shops; never the path.
  assertEquals(drops, {
    unreadable: 1,
    unreadableDomains: ["blocked.example"],
    noPrice: 2,
    noPriceDomains: ["zero.example", "noprice.example"],
    otherCurrency: {},
    outOfRange: 0,
  });

  // The cap leaves out search prices before checked ones.
  const capped = pickOffers(input, { currency: "USD", estimate: ticket.estimate, max: 2 });
  assertEquals(capped.offers.map((o) => o.store), ["Checked", "Blocked"]);
});

Deno.test("with no page checked, the cheapest search price is the one to start with", () => {
  const { offers } = pickOffers([
    { reported: reported("Walmart", 369, "USD"), page: null },
    { reported: reported("Target", 359.99, "USD"), page: { price: null, currency: null, title: null } },
  ], { currency: "USD", estimate: ticket.estimate, max: 5 });
  assertEquals(offers.map((o) => [o.store, o.price, o.checked, o.best]), [
    ["Target", 359.99, false, true],
    ["Walmart", 369, false, false],
  ]);
});

Deno.test("a search price needs the right currency and a typical price", () => {
  const { offers, drops } = pickOffers([
    { reported: reported("NoSearchPrice"), page: null },
    { reported: reported("Euros", 320, "EUR"), page: null },
    { reported: reported("Case", 29, "USD"), page: null },
    { reported: reported("Bundle", 1200, "USD"), page: { price: null, currency: "USD", title: null } },
    // The page shows another currency, so the search's dollars aren't used instead.
    { reported: reported("Pounds", 300, "USD"), page: { price: 280, currency: "GBP", title: null } },
  ], { currency: "USD", estimate: ticket.estimate, max: 5 });
  assertEquals(offers, []);
  assertEquals(drops.unreadable, 3);
  assertEquals(drops.noPrice, 1);
  assertEquals(drops.otherCurrency, { GBP: 1 });
});

Deno.test("offers in other currencies are counted by currency", () => {
  const { offers, drops } = pickOffers([
    { reported: reported("A"), page: { price: 349, currency: "USD", title: null } },
    { reported: reported("B"), page: { price: 329, currency: "USD", title: null } },
    { reported: reported("C"), page: { price: 299, currency: "EUR", title: null } },
    { reported: reported("D"), page: { price: 14999, currency: "UAH", title: null } },
  ], { currency: "UAH", estimate: null, max: 3 });
  assertEquals(offers.map((o) => o.store), ["D"]);
  assertEquals(drops.otherCurrency, { USD: 2, EUR: 1 });
});

Deno.test("the search log line has counts, currency codes and shop domains only", () => {
  const line = describeOffersSearch({
    model: "claude-haiku-5-5",
    searches: 2,
    suggested: 5,
    shopPages: 3,
    drops: {
      unreadable: 1,
      unreadableDomains: ["rozetka.com.ua"],
      noPrice: 0,
      noPriceDomains: [],
      otherCurrency: { USD: 1, EUR: 1 },
      outOfRange: 0,
    },
    found: 1,
    fromSearch: 1,
    latencyMs: 9129,
  });
  assertEquals(
    line,
    "identify-product: offers model=claude-haiku-5-5 searches=2 suggested=5 skipped=2 unreadable=1 " +
      "unreadable_domains=rozetka.com.ua no_price=0 no_price_domains=- other_currency=EUR:1,USD:1 " +
      "out_of_range=0 found=1 from_search=1 latency_ms=9129",
  );
  assertEquals(reportedCount({ offers: [{}, {}, {}] }), 3);
  assertEquals(reportedCount(null), 0);
  assertEquals(reportedCount({ offers: "x" }), 0);
});
