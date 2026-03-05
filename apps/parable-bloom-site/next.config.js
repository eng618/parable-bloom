// Explicitly set the Turbopack root to avoid Next inferring workspace root.
// This resolves to the repository root (two levels up).
const path = require("path");
const ROOT = path.resolve(__dirname, "../../");

module.exports = {
  turbopack: {
    root: ROOT,
  },
};
