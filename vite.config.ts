import { defineConfig } from "vite-plus";

export default defineConfig({
  // tsdown によるバンドル設定
  pack: {
    entry: { index: "src/functions/messages.ts" },
    format: "cjs",
    platform: "node",
    fixedExtension: false,
    deps: {
      // tsdown <0.23 compatibility: resolve external dependency subpaths.
      // Remove to preserve subpath imports as written (the new default).
      // https://tsdown.dev/options/dependencies#deps-resolvedepsubpath
      resolveDepSubpath: true,
      neverBundle: [
        // Azure Functions ランタイムが提供するため外部化
        "@azure/functions",
        // node_modules はデプロイに含めるため外部化
        "botbuilder",
      ],
    },
  },

  // Oxlint による Lint 設定
  lint: {
    ignorePatterns: ["dist/**", "node_modules/**"],
  },

  // Oxfmt によるフォーマット設定
  fmt: {},

  // Vitest によるテスト設定
  test: {
    include: ["src/**/*.test.ts"],
    passWithNoTests: true,
  },
});
