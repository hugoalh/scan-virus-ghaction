import { join as pathJoin } from "node:path";
import escapeStringRegExp from "escape-string-regexp";
export const pathRoot = (() => {
    const value = process.env.SVGHA_ROOT;
    if (typeof value === "undefined") {
        throw new ReferenceError(`Environment variable \`SVGHA_ROOT\` is not defined!`);
    }
    return value;
})();
export const pathAssetsRootName = "assets";
export const pathAssetsRootAbsolute = pathJoin(pathRoot, pathAssetsRootName);
export const pathProgramsVersionFileName = "programs-version.json";
export const pathProgramsVersionFileAbsolute = pathJoin(pathRoot, pathProgramsVersionFileName);
const toolkitSet = ["*", "clamav", "yara"];
export const toolkit = (() => {
    const value = process.env.SVGHA_TOOLKIT;
    if (!toolkitSet.includes(value)) {
        throw new Error(`${value} is not a valid toolkit set!`);
    }
    return value;
})();
export const cwd = process.cwd();
export const patternCWD = escapeStringRegExp(cwd);
