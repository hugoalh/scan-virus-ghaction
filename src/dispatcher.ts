import { error as ghactionsError, getBooleanInput as ghactionsGetBooleanInput } from "@actions/core";
const githubActionsRunnerArchitectures = ["arm", "arm64", "x64", "x86"] as const;
export type GitHubActionsRunnerArchitecture = (typeof githubActionsRunnerArchitectures)[number];
export const runnerArchitecture: GitHubActionsRunnerArchitecture = ((): GitHubActionsRunnerArchitecture => {
	const value: string | undefined = process.env.RUNNER_ARCH?.toLowerCase();
	if (typeof value === "undefined") {
		throw new ReferenceError(`Environment variable \`RUNNER_ARCH\` is not defined!`);
	}
	if (!githubActionsRunnerArchitectures.includes(value as GitHubActionsRunnerArchitecture)) {
		throw new SyntaxError(`\`${value}\` (environment variable \`RUNNER_ARCH\` value) is not a valid GitHub Actions runner architecture!`);
	}
	return value as GitHubActionsRunnerArchitecture;
})();
const githubActionsRunnerOperateSystems = ["linux", "macos", "windows"] as const;
export type GitHubActionsRunnerOperateSystem = (typeof githubActionsRunnerOperateSystems)[number];
export const runnerOperateSystem: GitHubActionsRunnerOperateSystem = ((): GitHubActionsRunnerOperateSystem => {
	const value: string | undefined = process.env.RUNNER_OS?.toLowerCase();
	if (typeof value === "undefined") {
		throw new ReferenceError(`Environment variable \`RUNNER_OS\` is not defined!`);
	}
	if (!githubActionsRunnerOperateSystems.includes(value as GitHubActionsRunnerOperateSystem)) {
		throw new SyntaxError(`\`${value}\` (environment variable \`RUNNER_OS\` value) is not a valid GitHub Actions runner operate system!`);
	}
	return value as GitHubActionsRunnerOperateSystem;
})();
const toolForce: string | undefined = process.env.SCANVIRUS_GHACTION_TOOLFORCE?.toLowerCase();
export const clamavEnable: boolean = (typeof toolForce === "undefined") ? ghactionsGetBooleanInput("clamav_enable", {
	required: true,
	trimWhitespace: false
}) : (toolForce === "clamav");
export const yaraEnable: boolean = (typeof toolForce === "undefined") ? ghactionsGetBooleanInput("yara_enable", {
	required: true,
	trimWhitespace: false
}) : (toolForce === "yara");
if (!clamavEnable && !yaraEnable) {
	ghactionsError(`No tools are selected!`);
	process.exit(1);
}
/**
 * @access private
 * @param {Record<GitHubActionsRunnerOperateSystem, string>} route
 * @returns {string}
 */
function resolveRoutePath(route: Record<GitHubActionsRunnerOperateSystem, string>): string {
	return route[runnerOperateSystem];
}
const clamavPathConfig: string = resolveRoutePath({
	linux: "/etc/clamav",
	macos: "/usr/local/etc/clamav"
});
const clamavPathDatabase: string = resolveRoutePath({
	linux: "/var/lib/clamav"
});