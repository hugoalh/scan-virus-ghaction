import { readFile } from "node:fs/promises";
import { error as ghactionsError, getBooleanInput as ghactionsGetBooleanInput, getInput as ghactionsGetInput, getMultilineInput as ghactionsGetMultilineInput } from "@actions/core";
import { pathProgramsVersionFileAbsolute, toolkit } from "./control.js";
console.log(`Software Version: `);
console.table(JSON.parse(await readFile(pathProgramsVersionFileAbsolute, { encoding: "utf-8" })));
console.log(`Initialize.`);
function getBooleanInput(name, { required = true, trimWhitespace = false } = {}) {
    return ghactionsGetBooleanInput(name, { required, trimWhitespace });
}
const inputClamAVEnable = (toolkit === "*") ? getBooleanInput("clamav_enable") : (toolkit === "clamav");
const inputClamAVUpdate = (toolkit === "*" ||
    toolkit === "clamav") ? getBooleanInput("clamav_update") : false;
const inputClamAVUnofficialAssetsUse = ghactionsGetMultilineInput("clamav_unofficialassets_use", { trimWhitespace: false }).filter((value) => {
    return (value.length > 0);
}).map((value) => {
    return new RegExp(value, "iu");
});
const inputClamAVCustomAssetsArtifact = (() => {
    const raw = ghactionsGetInput("clamav_customassets_artifact", { trimWhitespace: false });
    if (raw.length === 0) {
        return undefined;
    }
    let value;
    try {
        value = Number(raw);
    }
    catch {
        throw new TypeError(`\`${raw}\` is not a number!`);
    }
    if (!(Number.isSafeInteger(value) && value >= 0)) {
        throw new RangeError(`Input \`clamav_customassets_artifact\` is not a number which is integer, positive, and safe!`);
    }
    return value;
})();
const inputClamAVCustomAssetsUse = ghactionsGetMultilineInput("clamav_customassets_use", { trimWhitespace: false }).filter((value) => {
    return (value.length > 0);
}).map((value) => {
    return new RegExp(value, "iu");
});
const inputYARAEnable = (toolkit === "*") ? getBooleanInput("yara_enable") : (toolkit === "yara");
const inputYARAUnofficialAssetsUse = ghactionsGetMultilineInput("yara_unofficialassets_use", { trimWhitespace: false }).filter((value) => {
    return (value.length > 0);
}).map((value) => {
    return new RegExp(value, "iu");
});
const inputYARACustomAssetsArtifact = (() => {
    const raw = ghactionsGetInput("yara_customassets_artifact", { trimWhitespace: false });
    if (raw.length === 0) {
        return undefined;
    }
    let value;
    try {
        value = Number(raw);
    }
    catch {
        throw new TypeError(`\`${raw}\` is not a number!`);
    }
    if (!(Number.isSafeInteger(value) && value >= 0)) {
        throw new RangeError(`Input \`yara_customassets_artifact\` is not a number which is integer, positive, and safe!`);
    }
    return value;
})();
const inputYARACustomAssetsUse = ghactionsGetMultilineInput("yara_customassets_use", { trimWhitespace: false }).filter((value) => {
    return (value.length > 0);
}).map((value) => {
    return new RegExp(value, "iu");
});
const inputGitIntegrate = getBooleanInput("git_integrate");
const inputGitLFS = getBooleanInput("git_lfs");
const inputGitLimit = (() => {
    const raw = ghactionsGetInput("git_limit", {
        required: true,
        trimWhitespace: false
    });
    let value;
    try {
        value = BigInt(raw.replace(/n$/u, ""));
    }
    catch {
        throw new TypeError(`\`${raw}\` is not a bigint!`);
    }
    if (value < 0n) {
        throw new RangeError(`Input \`git_limit\` is not a bigint which is positive!`);
    }
    return value;
})();
const inputGitReverse = getBooleanInput("git_reverse");
const inputSummary = getBooleanInput("summary");
if (!inputClamAVEnable && !inputYARAEnable) {
    ghactionsError(`No tools are enabled!`);
    process.exit(1);
}
