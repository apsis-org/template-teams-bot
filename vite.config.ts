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
  fmt: {
    // release-please が自動生成するため整形対象外にする（整形すると次回の生成で差分が出続ける）
    ignorePatterns: ["CHANGELOG.md"],
  },

  // Vitest によるテスト設定
  test: {
    include: ["src/**/*.test.ts"],
    passWithNoTests: true,
  },
});
