/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    remotePatterns: [{ protocol: "https", hostname: "**" }],
  },
  experimental: {
    // Cover images are sent to the `uploadCover` server action as base64,
    // which inflates the payload ~33%. The default Server Action body limit
    // is 1 MB, so any cover photo over ~750 KB fails silently. Raise it so
    // normal phone/camera images (2–8 MB) upload reliably.
    serverActions: {
      bodySizeLimit: "12mb",
    },
  },
};

export default nextConfig;
