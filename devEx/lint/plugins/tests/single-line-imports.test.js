import { RuleTester } from "eslint";
import rule from "../custom/single-line-imports.js";

const ruleTester = new RuleTester({
    parserOptions: {
        ecmaVersion: 2021,
        sourceType: "module",
    },
});

ruleTester.run("single-line-import", rule, {
    valid: [
        {
            code: "import { foo, bar, baz } from 'module';",
        },
        {
            code: "import defaultExport, { foo, bar, baz as renamed } from 'module';",
        },
        {
            code: "import * as name from 'module';",
        },
        {
            code: "import 'module';",
        },
    ],
    invalid: [
        {
            code: `import {
                        foo,
                        bar,
                        baz
                    } from 'module';`,
            output: "import { foo, bar, baz } from 'module';",
            errors: [{ message: "Import statements must be on a single line" }],
        },
        {
            code: `import defaultExport, {
                        foo,
                        bar,
                        baz as renamed
                    } from 'module';`,
            output: "import defaultExport, { foo, bar, baz as renamed } from 'module';",
            errors: [{ message: "Import statements must be on a single line" }],
        },
        {
            code: `import {
                        reallyLongImportName1,
                        reallyLongImportName2,
                        reallyLongImportName3,
                        reallyLongImportName4,
                    } from 'really-long-module-name';`,
            output: "import { reallyLongImportName1, reallyLongImportName2, reallyLongImportName3, reallyLongImportName4 } from 'really-long-module-name';",
            errors: [{ message: "Import statements must be on a single line" }],
        },
    ],
});

export default ruleTester
