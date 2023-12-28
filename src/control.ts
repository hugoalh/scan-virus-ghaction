import escapeStringRegExp from "escape-string-regexp";
const toolSet = ["*", "clamav", "yara"] as const;
export type ScanVirusGitHubActionToolSet = typeof toolSet[number];
export const toolKit: ScanVirusGitHubActionToolSet = ((): ScanVirusGitHubActionToolSet => {
	const value: string = process.env.SVGHA_TOOLKIT ?? "*";
	if (!toolSet.includes(value as ScanVirusGitHubActionToolSet)) {
		throw new Error(`${value} is not a valid tool set!`);
	}
	return value as ScanVirusGitHubActionToolSet;
})();
export const cwd: string = process.cwd();
export const patternCWD: string = escapeStringRegExp(cwd);
