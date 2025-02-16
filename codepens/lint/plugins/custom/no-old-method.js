export default {
    meta: {
        type: "problem",
        hasSuggestions: true,
        fixable: true,
    },

    create(context) {
        return {
            CallExpression(node) {
                if (node.callee.name == "oldMethodName") {
                    context.report({
                        node,
                        message: "Do not use oldMethodName in code",

                        fix(fixer) {
                            return [
                                fixer.replaceTextRange(
                                    [node.start, node.end],
                                    "newMethodName()"
                                ),
                            ];
                        },
                    });
                }
            },
        };
    },
};
