import globals from "globals";
import path from "node:path";
import url from "node:url";
import customLintRulesPlugin from "eslint-plugin-custom";
import { FlatCompat } from "@eslint/eslintrc";

export default [
    ...new FlatCompat({
        baseDirectory: path.dirname(url.fileURLToPath(import.meta.url)),
    }).config(
        { languageOptions: { globals: globals.browser } },
        {
            plugins: {
                custom: customLintRulesPlugin,
            },
            rules: {
                "no-console": "warn",
                "no-unused-vars": "warn",
                "no-undef": "warn",
                "custom/no-old-method": "error",
                "custom/multi-line-ternary": "warn",
                "custom/single-line-import": "error",
            },
        }
    ),
];
