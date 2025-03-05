export default {
    meta: {
        type: "layout",
        docs: {
            description: "Enforce single-line import statements",
            category: "Stylistic Issues",
            recommended: false,
        },
        fixable: "whitespace",
        schema: [], // no options
    },
    create(context) {
        const sourceCode = context.getSourceCode();

        return {
            ImportDeclaration(node) {
                const firstToken = sourceCode.getFirstToken(node);
                const lastToken = sourceCode.getLastToken(node);

                // Check if the import statement spans multiple lines
                if (firstToken.loc.start.line !== lastToken.loc.end.line) {
                    context.report({
                        node,
                        message: "Import statements must be on a single line",
                        fix(fixer) {
                            // Get all tokens including comments
                            const tokens = sourceCode.getTokens(node);

                            // Convert multiline import to single line
                            const singleLineImport = tokens
                                .map((token) => token.value)
                                .join(" ")
                                .replace(/\s*,\s*/g, ", ") // Normalize spaces around commas
                                .replace(/\s*{\s*/g, "{ ") // Normalize spaces around opening brace
                                .replace(/\s*}\s*/g, " }") // Normalize spaces around closing brace
                                .replace(/\s+/g, " "); // Remove extra spaces

                            return fixer.replaceText(node, singleLineImport);
                        },
                    });
                }
            },
        };
    },
};
