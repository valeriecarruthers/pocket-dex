import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    // Sprites come from the PokeAPI sprite repository on GitHub.
    remotePatterns: [new URL("https://raw.githubusercontent.com/PokeAPI/sprites/**")],
    // The dataset points at ~1,300 already-optimised PNGs on a CDN. Running them
    // through the image optimiser would add cost and latency for no visual gain.
    unoptimized: true,
  },
};

export default nextConfig;
