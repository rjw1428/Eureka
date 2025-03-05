export default {
    meta: {
        type: "layout",
        docs: {
            description: "Enforce specific formatting for ternary expressions",
            category: "Stylistic Issues",
            recommended: false,
        },
        fixable: "whitespace",
        schema: [], // no options
    },
    create(context) {
        const sourceCode = context.getSourceCode();
        const INDENT_SIZE = 2; // Default indent size

        function getNodeIndent(node) {
            const token = sourceCode.getFirstToken(node);
            const lineStart = token.loc.start.line;
            const line = sourceCode.lines[lineStart - 1];
            const indentMatch = line.match(/^\s*/);
            return indentMatch
            ?   indentMatch[0].length
            :   0;
        }

        return {
            ConditionalExpression(node) {
                const testToken = sourceCode.getFirstToken(node.test);
                const questionToken = sourceCode.getTokenAfter(node.test);
                const colonToken = sourceCode.getTokenBefore(node.alternate);

                const baseIndent = getNodeIndent(node.test);
                const expectedConsequentIndent = baseIndent + INDENT_SIZE;
                const expectedAlternateIndent = baseIndent + INDENT_SIZE;

                const testLine = testToken.loc.start.line;
                const questionLine = questionToken.loc.start.line;
                const consequentLine = node.consequent.loc.start.line;
                const colonLine = colonToken.loc.start.line;
                const alternateLine = node.alternate.loc.start.line;

                // Get actual indents
                const consequentIndent =
                    getNodeIndent(node.consequent) - INDENT_SIZE; // Subtract ? width
                const alternateIndent =
                    getNodeIndent(node.alternate) - INDENT_SIZE; // Subtract : width

                const isFormatCorrect =
                    testLine < questionLine && // condition on first line
                    questionLine === consequentLine && // ? and true case on second line
                    consequentLine < colonLine && // true case ends before colon
                    colonLine === alternateLine && // : and false case on third line
                    consequentIndent === expectedConsequentIndent && // correct true case indent
                    alternateIndent === expectedAlternateIndent; // correct false case indent

                if (!isFormatCorrect) {
                    context.report({
                        node,
                        message:
                            "Ternary expressions must span exactly 3 lines with proper indentation",
                        fix(fixer) {
                            const testText = sourceCode.getText(node.test);
                            const consequentText = sourceCode.getText(
                                node.consequent
                            );
                            const alternateText = sourceCode.getText(
                                node.alternate
                            );

                            const baseIndentStr = " ".repeat(baseIndent);
                            const extraIndentStr = " ".repeat(INDENT_SIZE);

                            return fixer.replaceText(
                                node,
                                `${testText}\n${baseIndentStr}? ${extraIndentStr}${consequentText}\n${baseIndentStr}: ${extraIndentStr}${alternateText}`
                            );
                        },
                    });
                }
            },
        };
    },
};
