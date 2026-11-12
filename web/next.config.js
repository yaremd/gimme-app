/** @type {import('next').NextConfig} */
const nextConfig = {
  // Injected at build time. Used to cache-bust the OG image URL per deploy
  // so Facebook/Slack/iMessage refetch the rendered Card after each deploy
  // instead of holding the @vercel/og default 1-year immutable cache forever.
  env: {
    BUILD_ID: Date.now().toString(36),
  },
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "**" },
    ],
  },
  async headers() {
    return [
      {
        // Apple requires the AASA to be served as application/json
        source: "/.well-known/apple-app-site-association",
        headers: [
          { key: "Content-Type", value: "application/json" },
        ],
      },
    ];
  },
};

module.exports = nextConfig;
