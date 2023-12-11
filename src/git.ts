import { randomUUID } from "node:crypto";
import { error as ghactionsError, warning as ghactionsWarn } from "@actions/core";
import { executeChildProcess, type ChildProcessResult } from "./execute.js";
export interface GitCommitMeta {
	authorDate: Date;
	authorEmail: string;
	authorName: string;
	body: string;
	commitHash: string;
	committerDate: Date;
	committerEmail: string;
	committerName: string;
	encoding: string;
	notes: string;
	parentHashes: string[];
	reflogIdentityEmail: string;
	reflogIdentityName: string;
	reflogSelector: string;
	reflogSubject: string;
	subject: string;
	treeHash: string;
}
interface GitCommitPropertyMeta {
	asIndex?: boolean;
	name: string;
	placeholder: string;
	transform?: (item: string) => unknown;
}
const gitCommitPropertiesMeta: GitCommitPropertyMeta[] = [
	{
		name: "authorDate",
		placeholder: "%aI",
		transform: (item: string): Date => {
			return new Date(item);
		}
	},
	{
		name: "authorEmail",
		placeholder: "%ae"
	},
	{
		name: "authorName",
		placeholder: "%an"
	},
	{
		name: "body",
		placeholder: "%b"
	},
	{
		name: "commitHash",
		placeholder: "%H",
		asIndex: true
	},
	{
		name: "committerDate",
		placeholder: "%cI",
		transform: (item: string): Date => {
			return new Date(item);
		}
	},
	{
		name: "committerEmail",
		placeholder: "%ce"
	},
	{
		name: "committerName",
		placeholder: "%cn"
	},
	{
		name: "encoding",
		placeholder: "%e"
	},
	{
		name: "notes",
		placeholder: "%N"
	},
	{
		name: "parentHashes",
		placeholder: "%P",
		transform: (item: string): string[] => {
			return item.split(" ");
		}
	},
	{
		name: "reflogIdentityEmail",
		placeholder: "%ge"
	},
	{
		name: "reflogIdentityName",
		placeholder: "%gn"
	},
	{
		name: "reflogSelector",
		placeholder: "%gD"
	},
	{
		name: "reflogSubject",
		placeholder: "%gs"
	},
	{
		name: "subject",
		placeholder: "%s"
	},
	{
		name: "treeHash",
		placeholder: "%T"
	}
];
const gitCommitPropertyMetaIndexer: GitCommitPropertyMeta = gitCommitPropertiesMeta.filter((property: GitCommitPropertyMeta): boolean => {
	return property.asIndex;
})[0];
await executeChildProcess(["git", "--no-pager", "config", "--global", "--add", "safe.directory", process.cwd()], { shell: true });
export async function disableGitLFSProcess(): Promise<void> {
	try {
		await executeChildProcess(["git", "--no-pager", "config", "--global", "filter.lfs.process", "git-lfs filter-process --skip", "*>&1"], { shell: true });
		await executeChildProcess(["git", "--no-pager", "config", "--global", "filter.lfs.smudge", "git-lfs smudge --skip -- %f", "*>&1"], { shell: true });
	} catch (error) {
		ghactionsWarn(`Unable to disable Git LFS process: ${error}`);
	}
}
export async function getGitCommitsIndex(sortFromOldest = false): Promise<string[]> {
	const command: string[] = ["git", "--no-pager", "log", `--format=${gitCommitPropertyMetaIndexer.placeholder}`, "--no-color", "--all", "--reflog"];
	if (sortFromOldest) {
		command.push("--reverse");
	}
	command.push("*>&1");
	const result: ChildProcessResult = await executeChildProcess(command, { shell: true });
	if (result.code === 0) {
		return result.stdout.split(/\r?\n/gu);
	}
	ghactionsError(`Unable to get Git commit index: ${result.stdout}`);
	return [];
}
export async function getGitCommitMeta(index: string): Promise<GitCommitMeta | undefined> {
	let delimiterToken: string;
	let result: string[];
	do {
		delimiterToken = randomUUID().replace(/-/gu, "");
		try {
			const output: ChildProcessResult = await executeChildProcess(["git", "--no-pager", "show", `--format=${gitCommitPropertiesMeta.map((property: GitCommitPropertyMeta): string => {
				return property.placeholder;
			}).join(`%n${delimiterToken}%n`)}`, "--no-color", "--no-patch", index, "*>&1"], { shell: true });
			if (!output.success) {
				throw output.stdout;
			}
			result = output.stdout.split(new RegExp(`\\r?\\n${delimiterToken}\\r?\\n`, "gu"));
		} catch (error) {
			ghactionsError(`Unable to get Git commit meta ${index}: ${error}`);
			return;
		}
	} while (result.length !== gitCommitPropertiesMeta.length);
	const gitCommitMeta: Partial<GitCommitMeta> = {};
	for (let line = 0; line < result.length; line += 1) {
		const gitCommitProperty: GitCommitPropertyMeta = gitCommitPropertiesMeta[line];
		const value: string = result[line];
		gitCommitMeta[gitCommitProperty.name] = (typeof gitCommitProperty.transform === "undefined") ? value : gitCommitProperty.transform(value);
	}
	return gitCommitMeta as GitCommitMeta;
}
export async function isGitRepository(): Promise<boolean> {
	try {
		const result: ChildProcessResult = await executeChildProcess(["git", "--no-pager", "rev-parse", "--is-inside-work-tree", "*>&1"], { shell: true });
		if (result.stdout.toLowerCase() === "true") {
			return true;
		}
		throw result.stdout;
	} catch (error) {
		ghactionsError(`Unable to integrate with Git: ${error}`);
		return false;
	}
}
