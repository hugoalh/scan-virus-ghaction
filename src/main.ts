import { readFile } from "node:fs/promises";
import { endGroup as ghactionsEndGroup, error as ghactionsError, getBooleanInput as ghactionsGetBooleanInput, getInput as ghactionsGetInput, getMultilineInput as ghactionsGetMultilineInput, startGroup as ghactionsStartGroup } from "@actions/core";
import { pathProgramsVersionFileAbsolute, toolkit } from "./control.js";
ghactionsStartGroup(`Software Version: `);
console.table(JSON.parse(await readFile(pathProgramsVersionFileAbsolute, { encoding: "utf-8" })));
ghactionsEndGroup();
console.log(`Initialize.`);
const inputClamAVEnable: boolean = (toolkit === "*") ? ghactionsGetBooleanInput("clamav_enable", {
	required: true,
	trimWhitespace: false
}) : toolkit === "clamav";
const inputClamAVUpdate: boolean = (
	toolkit === "*" ||
	toolkit === "clamav"
) ? ghactionsGetBooleanInput("clamav_update", {
	required: true,
	trimWhitespace: false
}) : false;
const inputClamAVUnofficialAssetsUse: RegExp[] = ghactionsGetMultilineInput("clamav_unofficialassets_use", { trimWhitespace: false }).filter((value: string): boolean => {
	return (value.length > 0);
}).map((value: string): RegExp => {
	return new RegExp(value, "iu");
});
const inputClamAVCustomAssetsArtifact: string = ghactionsGetInput("clamav_customassets_artifact", { trimWhitespace: false });
const inputClamAVCustomAssetsUse: RegExp[] = ghactionsGetMultilineInput("clamav_customassets_use", { trimWhitespace: false }).filter((value: string): boolean => {
	return (value.length > 0);
}).map((value: string): RegExp => {
	return new RegExp(value, "iu");
});
const inputYARAEnable: boolean = (toolkit === "*") ? ghactionsGetBooleanInput("yara_enable", {
	required: true,
	trimWhitespace: false
}) : toolkit === "yara";
const inputYARAUnofficialAssetsUse: RegExp[] = ghactionsGetMultilineInput("yara_unofficialassets_use", { trimWhitespace: false }).filter((value: string): boolean => {
	return (value.length > 0);
}).map((value: string): RegExp => {
	return new RegExp(value, "iu");
});
const inputYARACustomAssetsArtifact: string = ghactionsGetInput("yara_customassets_artifact", { trimWhitespace: false });
const inputYARACustomAssetsUse: RegExp[] = ghactionsGetMultilineInput("yara_customassets_use", { trimWhitespace: false }).filter((value: string): boolean => {
	return (value.length > 0);
}).map((value: string): RegExp => {
	return new RegExp(value, "iu");
});
const inputGitIntegrate: boolean = ghactionsGetBooleanInput("git_integrate", {
	required: true,
	trimWhitespace: false
});
const inputGitLFS: boolean = ghactionsGetBooleanInput("git_lfs", {
	required: true,
	trimWhitespace: false
});
const inputGitLimit: bigint = ((): bigint => {
	const raw: string = ghactionsGetInput("git_limit", {
		required: true,
		trimWhitespace: false
	});
	if (!/^(?:0|[1-9]\d*)n?$/u.test(raw)) {
		throw new TypeError(`\`${raw}\` is not a big integer!`);
	}
	const value = BigInt(raw);
	if (value < 0n) {
		throw new RangeError(`Input \`git_limit\` is not a bigint which is positive!`);
	}
	return value;
})();
const inputGitReverse: boolean = ghactionsGetBooleanInput("git_reverse", {
	required: true,
	trimWhitespace: false
});
const inputSummary: boolean = ghactionsGetBooleanInput("summary", {
	required: true,
	trimWhitespace: false
});
if (!inputClamAVEnable && !inputYARAEnable) {
	ghactionsError(`No tools are enabled!`);
	process.exit(1);
}
