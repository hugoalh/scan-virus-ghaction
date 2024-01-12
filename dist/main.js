import { readFile } from "node:fs/promises";
import { endGroup as ghactionsEndGroup, error as ghactionsError, getBooleanInput as ghactionsGetBooleanInput, getInput as ghactionsGetInput, getMultilineInput as ghactionsGetMultilineInput, startGroup as ghactionsStartGroup } from "@actions/core";
import { pathProgramsVersionFileAbsolute, toolkit } from "./control.js";
ghactionsStartGroup(`Software Version: `);
console.table(JSON.parse(await readFile(pathProgramsVersionFileAbsolute, { encoding: "utf-8" })));
ghactionsEndGroup();
console.log(`Initialize.`);
const inputClamAVEnable = (toolkit === "*") ? ghactionsGetBooleanInput("clamav_enable", {
    required: true,
    trimWhitespace: false
}) : toolkit === "clamav";
const inputClamAVUpdate = (toolkit === "*" ||
    toolkit === "clamav") ? ghactionsGetBooleanInput("clamav_update", {
    required: true,
    trimWhitespace: false
}) : false;
const inputClamAVUnofficialAssetsUse = ghactionsGetMultilineInput("clamav_unofficialassets_use", { trimWhitespace: false }).filter((value) => {
    return (value.length > 0);
}).map((value) => {
    return new RegExp(value, "iu");
});
const inputClamAVCustomAssetsArtifact = ghactionsGetInput("clamav_customassets_artifact", { trimWhitespace: false });
const inputClamAVCustomAssetsUse = ghactionsGetMultilineInput("clamav_customassets_use", { trimWhitespace: false }).filter((value) => {
    return (value.length > 0);
}).map((value) => {
    return new RegExp(value, "iu");
});
const inputYARAEnable = (toolkit === "*") ? ghactionsGetBooleanInput("yara_enable", {
    required: true,
    trimWhitespace: false
}) : toolkit === "yara";
const inputYARAUnofficialAssetsUse = ghactionsGetMultilineInput("yara_unofficialassets_use", { trimWhitespace: false }).filter((value) => {
    return (value.length > 0);
}).map((value) => {
    return new RegExp(value, "iu");
});
const inputYARACustomAssetsArtifact = ghactionsGetInput("yara_customassets_artifact", { trimWhitespace: false });
const inputYARACustomAssetsUse = ghactionsGetMultilineInput("yara_customassets_use", { trimWhitespace: false }).filter((value) => {
    return (value.length > 0);
}).map((value) => {
    return new RegExp(value, "iu");
});
const inputGitIntegrate = ghactionsGetBooleanInput("git_integrate", {
    required: true,
    trimWhitespace: false
});
const inputGitLFS = ghactionsGetBooleanInput("git_lfs", {
    required: true,
    trimWhitespace: false
});
const inputGitLimit = (() => {
    const raw = ghactionsGetInput("git_limit", {
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
const inputGitReverse = ghactionsGetBooleanInput("git_reverse", {
    required: true,
    trimWhitespace: false
});
const inputSummary = ghactionsGetBooleanInput("summary", {
    required: true,
    trimWhitespace: false
});
if (!inputClamAVEnable && !inputYARAEnable) {
    ghactionsError(`No tools are enabled!`);
    process.exit(1);
}
