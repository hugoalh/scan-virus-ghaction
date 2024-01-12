import { readFile } from "node:fs/promises";
import { InputOptions as GitHubActionsGetInputOptions, endGroup as ghactionsEndGroup, error as ghactionsError, getBooleanInput as ghactionsGetBooleanInput, getInput as ghactionsGetInput, getMultilineInput as ghactionsGetMultilineInput, startGroup as ghactionsStartGroup } from "@actions/core";
import { pathProgramsVersionFileAbsolute, toolkit } from "./control.js";
console.log(`Software Version: `);
console.table(JSON.parse(await readFile(pathProgramsVersionFileAbsolute, { encoding: "utf-8" })));
console.log(`Initialize.`);
function getBooleanInput(name: string, { required = true, trimWhitespace = false }: GitHubActionsGetInputOptions = {}): boolean {
	return ghactionsGetBooleanInput(name, { required, trimWhitespace });
}
const inputClamAVEnable: boolean = (toolkit === "*") ? getBooleanInput("clamav_enable") : (toolkit === "clamav");
const inputClamAVUpdate: boolean = (
	toolkit === "*" ||
	toolkit === "clamav"
) ? getBooleanInput("clamav_update") : false;
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
	let value: number;
	try {
		value = Number(raw);
	} catch {
		throw new TypeError(`\`${raw}\` is not a number!`);
	}
	if (!(Number.isSafeInteger(value) && value >= 0)) {
		throw new RangeError(`Input \`clamav_customassets_artifact\` is not a number which is integer, positive, and safe!`);
	}
	return value;
})();
const inputClamAVCustomAssetsUse: RegExp[] = ghactionsGetMultilineInput("clamav_customassets_use", { trimWhitespace: false }).filter((value: string): boolean => {
	return (value.length > 0);
}).map((value: string): RegExp => {
	return new RegExp(value, "iu");
});
const inputYARAEnable: boolean = (toolkit === "*") ? getBooleanInput("yara_enable") : (toolkit === "yara");
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
	let value: number;
	try {
		value = Number(raw);
	} catch {
		throw new TypeError(`\`${raw}\` is not a number!`);
	}
	if (!(Number.isSafeInteger(value) && value >= 0)) {
		throw new RangeError(`Input \`yara_customassets_artifact\` is not a number which is integer, positive, and safe!`);
	}
	return value;
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
	let value: bigint;
	try {
		value = BigInt(raw.replace(/n$/u, ""));
	} catch {
		throw new TypeError(`\`${raw}\` is not a bigint!`);
	}
	if (value < 0n) {
		throw new RangeError(`Input \`git_limit\` is not a bigint which is positive!`);
	}
	return value;
})();
const inputGitReverse: boolean = getBooleanInput("git_reverse");
const inputSummary: boolean = getBooleanInput("summary");
if (!inputClamAVEnable && !inputYARAEnable) {
	ghactionsError(`No tools are enabled!`);
	process.exit(1);
}
