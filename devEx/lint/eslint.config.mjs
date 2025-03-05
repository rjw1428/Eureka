import globals from "globals";
import pluginJs from "@eslint/js";
import customLintRulesPlugin from "eslint-plugin-custom";

export default [
    { languageOptions: { globals: globals.browser } },
    pluginJs.configs.recommended,
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
    },
];
