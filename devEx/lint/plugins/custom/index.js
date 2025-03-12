import noOldMethod from "./no-old-method.js";
import singleLineImports from "./single-line-imports.js";
import ternaryFormat from "./ternary-format.js"

export default {
    rules: {
        'no-old-method': noOldMethod,
        'multi-line-ternary': ternaryFormat,
        'single-line-import': singleLineImports
    }
}