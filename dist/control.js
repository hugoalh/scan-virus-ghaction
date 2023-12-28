import escapeStringRegExp from "escape-string-regexp";
const toolSet = ["*", "clamav", "yara"];
export const toolKit = (() => {
    const value = process.env.SVGHA_TOOLKIT ?? "*";
    if (!toolSet.includes(value)) {
        throw new Error(`${value} is not a valid tool set!`);
    }
    return value;
})();
export const cwd = process.cwd();
export const patternCWD = escapeStringRegExp(cwd);
