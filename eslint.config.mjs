// ESLint flat config: core recommended for scripts plus TypeScript
// recommended scoped to TypeScript sources, with no suppressions.
// Next-specific rules (eslint-config-next) are deliberately not included:
// resolving that pack re-resolves the shared `next` dependency for every
// parallel lane, so this records only the framework-free core.
//
// The Node acceptance scripts are real CommonJS (`require`, `__dirname`,
// `process`, `fetch`), so the TypeScript require-import rule is lifted for
// `*.cjs` only; TypeScript sources keep it. Plain Node tests never receive
// TypeScript-only rules: each recommended set applies solely to its own
// file kinds.
import js from "@eslint/js";
import tseslint from "typescript-eslint";

const nodeGlobals = {
  require: "readonly",
  module: "readonly",
  exports: "writable",
  __dirname: "readonly",
  __filename: "readonly",
  process: "readonly",
  Buffer: "readonly",
  console: "readonly",
  setTimeout: "readonly",
  clearTimeout: "readonly",
  setInterval: "readonly",
  clearInterval: "readonly",
  queueMicrotask: "readonly",
  fetch: "readonly",
  Response: "readonly",
  FormData: "readonly",
  File: "readonly",
  Blob: "readonly",
  URL: "readonly",
  URLSearchParams: "readonly",
};

const browserGlobals = {
  window: "readonly",
  document: "readonly",
  navigator: "readonly",
  location: "readonly",
  history: "readonly",
  localStorage: "readonly",
  sessionStorage: "readonly",
  fetch: "readonly",
  URL: "readonly",
  URLSearchParams: "readonly",
  Blob: "readonly",
  File: "readonly",
  FileReader: "readonly",
  FormData: "readonly",
  requestAnimationFrame: "readonly",
  cancelAnimationFrame: "readonly",
  setTimeout: "readonly",
  clearTimeout: "readonly",
  setInterval: "readonly",
  clearInterval: "readonly",
  queueMicrotask: "readonly",
  console: "readonly",
};

export default tseslint.config(
  {
    ignores: ["node_modules/**", ".next/**", "out/**", "storage/**", "coverage/**"],
  },
  {
    files: ["**/*.js", "**/*.mjs", "**/*.cjs"],
    extends: [js.configs.recommended],
  },
  {
    files: ["**/*.ts", "**/*.tsx", "**/*.mts", "**/*.cts"],
    extends: [...tseslint.configs.recommended],
  },
  {
    files: ["**/*.cjs"],
    languageOptions: { sourceType: "commonjs", globals: nodeGlobals },
    rules: { "@typescript-eslint/no-require-imports": "off" },
  },
  {
    files: ["scripts/**/*.mjs"],
    languageOptions: { sourceType: "module", globals: nodeGlobals },
  },
  {
    files: ["app/**/*.{ts,tsx}", "components/**/*.{ts,tsx}", "lib/**/*.{ts,tsx}"],
    languageOptions: { globals: browserGlobals },
  },
);
