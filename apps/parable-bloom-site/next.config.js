// Explicitly set the Turbopack root to avoid Next inferring workspace root.
// This resolves to the repository root (two levels up).
const path = require("path");
const ROOT = path.resolve(__dirname, "../../");

module.exports = {
  // Write Next's build output to `apps/parable-bloom-site/build` so deploy
  // systems (e.g. Cloudflare Pages) can find artifacts in a predictable path.
  distDir: "build",
  turbopack: {
    root: ROOT,
  },
};
