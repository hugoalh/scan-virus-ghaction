import escapeStringRegExp from "escape-string-regexp";
export interface SVGHAProgramVersion {
	"Name": string;
	"Version": string;
}
const toolSet = ["*", "clamav", "yara"] as const;
export type SVGHAToolSet = typeof toolSet[number];
export const toolKit: SVGHAToolSet = ((): SVGHAToolSet => {
	const value: string = process.env.SVGHA_TOOLKIT ?? "*";
	if (!toolSet.includes(value as SVGHAToolSet)) {
		throw new Error(`${value} is not a valid tool set!`);
	}
	return value as SVGHAToolSet;
})();
export const cwd: string = process.cwd();
export const patternCWD: string = escapeStringRegExp(cwd);
