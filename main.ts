import { InputOptions as GitHubActionsGetInputOptions, endGroup as ghactionsEndGroup, error as ghactionsError, getBooleanInput as ghactionsGetBooleanInput, getInput as ghactionsGetInput, getMultilineInput as ghactionsGetMultilineInput, startGroup as ghactionsStartGroup } from "GITHUB_ACTIONS_CORE";
import { pathProgramsVersionFileAbsolute } from "./lib/control.ts";
console.log("Programs Version: ");
console.table(JSON.parse(await Deno.readTextFile(pathProgramsVersionFileAbsolute)));
console.log(`Initialize.`);
function getBooleanInput(name: string, { required = true, trimWhitespace = false }: GitHubActionsGetInputOptions = {}): boolean {
	return ghactionsGetBooleanInput(name, { required, trimWhitespace });
}
const inputClamAVEnable: boolean = getBooleanInput("clamav_enable");
const inputClamAVUpdate: boolean = getBooleanInput("clamav_update");
const inputClamAVUnofficialAssetsUse: RegExp[] = ghactionsGetMultilineInput("clamav_unofficialassets_use", { trimWhitespace: false }).filter((value: string): boolean => {
	return (value.length > 0);
}).map((value: string): RegExp => {
	return new RegExp(value, "iu");
});
const inputClamAVCustomAssetsArtifact: number | undefined = ((): number | undefined => {
	const raw: string = ghactionsGetInput("clamav_customassets_artifact", { trimWhitespace: false });
	if (raw.length === 0) {
		return undefined;
	}
	try {
		const value = Number(raw);
		if (!(Number.isSafeInteger(value) && value >= 0)) {
			throw undefined;
		}
		return value;
	} catch {
		throw new RangeError(`Input \`clamav_customassets_artifact\` is not a number which is integer, positive, and safe!`);
	}
})();
const inputClamAVCustomAssetsUse: RegExp[] = ghactionsGetMultilineInput("clamav_customassets_use", { trimWhitespace: false }).filter((value: string): boolean => {
	return (value.length > 0);
}).map((value: string): RegExp => {
	return new RegExp(value, "iu");
});
const inputYARAEnable: boolean = getBooleanInput("yara_enable");
const inputYARAUnofficialAssetsUse: RegExp[] = ghactionsGetMultilineInput("yara_unofficialassets_use", { trimWhitespace: false }).filter((value: string): boolean => {
	return (value.length > 0);
}).map((value: string): RegExp => {
	return new RegExp(value, "iu");
});
const inputYARACustomAssetsArtifact: number | undefined = ((): number | undefined => {
	const raw: string = ghactionsGetInput("yara_customassets_artifact", { trimWhitespace: false });
	if (raw.length === 0) {
		return undefined;
	}
	try {
		const value = Number(raw);
		if (!(Number.isSafeInteger(value) && value >= 0)) {
			throw undefined;
		}
		return value;
	} catch {
		throw new RangeError(`Input \`yara_customassets_artifact\` is not a number which is integer, positive, and safe!`);
	}
})();
const inputYARACustomAssetsUse: RegExp[] = ghactionsGetMultilineInput("yara_customassets_use", { trimWhitespace: false }).filter((value: string): boolean => {
	return (value.length > 0);
}).map((value: string): RegExp => {
	return new RegExp(value, "iu");
});
const inputGitIntegrate: boolean = getBooleanInput("git_integrate");
const inputGitLFS: boolean = getBooleanInput("git_lfs");
const inputGitLimit: bigint = ((): bigint => {
	const raw: string = ghactionsGetInput("git_limit", {
		required: true,
		trimWhitespace: false
	});
	try {
		const value = BigInt(raw.replace(/n$/u, ""));
		if (value < 0n) {
			throw undefined;
		}
		return value;
	} catch {
		throw new RangeError(`Input \`git_limit\` is not a bigint which is positive!`);
	}
})();
const inputGitReverse: boolean = getBooleanInput("git_reverse");
const inputSummary: boolean = getBooleanInput("summary");
if (!inputClamAVEnable && !inputYARAEnable) {
	ghactionsError(`No tools are enabled!`);
	Deno.exit(1);
}
