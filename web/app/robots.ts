import { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: "/",
      // /auth is the password-reset hand-off; /options is a local design preview
      // that does not exist on the live site.
      disallow: ["/auth/", "/options/"],
    },
    sitemap: "https://gimmelist.com/sitemap.xml",
  };
}
