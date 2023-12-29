import { join as pathJoin } from "node:path";
import escapeStringRegExp from "escape-string-regexp";
export const pathRoot: string = ((): string => {
	const value: string | undefined = process.env.SVGHA_ROOT;
	if (typeof value === "undefined") {
		throw new Error(`Environment variable \`SVGHA_ROOT\` is missing!`);
	}
	return value;
})();
export const pathAssetsRootName = "assets";
export const pathAssetsRootAbsolute: string = pathJoin(pathRoot, pathAssetsRootName);
export const pathProgramsVersionFileName = "programs-version.json";
export const pathProgramsVersionFileAbsolute: string = pathJoin(pathRoot, pathProgramsVersionFileName);
const toolkitSet = ["*", "clamav", "yara"] as const;
export type SVGHAToolkitSet = typeof toolkitSet[number];
export const toolkit: SVGHAToolkitSet = ((): SVGHAToolkitSet => {
	const value: string | undefined = process.env.SVGHA_TOOLKIT;
	if (!toolkitSet.includes(value as SVGHAToolkitSet)) {
		throw new Error(`${value} is not a valid toolkit set!`);
	}
	return value as SVGHAToolkitSet;
})();
export const cwd: string = process.cwd();
export const patternCWD: string = escapeStringRegExp(cwd);
