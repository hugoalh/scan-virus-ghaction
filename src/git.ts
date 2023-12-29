import { error as ghactionsError } from "@actions/core";
import { cwd } from "./control.js";
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
interface GitCommitsProperty {
	asIndex?: boolean;
	name: keyof GitCommitMeta;
	placeholder: `%${string}`;
	transform?: (item: string) => unknown;
}
const gitCommitsProperties: GitCommitsProperty[] = [
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
		asIndex: true,
		name: "commitHash",
		placeholder: "%H"
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
const gitCommitsPropertyIndexer: GitCommitsProperty = gitCommitsProperties.filter((property: GitCommitsProperty): boolean => {
	return property.asIndex ?? false;
})[0];
await executeChildProcess(["git", "--no-pager", "config", "--global", "--add", "safe.directory", cwd]).then((result: ChildProcessResult): void => {
	if (!result.success) {
		console.error(result.stderr);
		process.exit(result.code);
	}
});
export async function disableGitLFSProcess(): Promise<void> {
	try {
		await executeChildProcess(["git", "--no-pager", "config", "--global", "filter.lfs.process", "git-lfs filter-process --skip"]).then((result: ChildProcessResult): void => {
			if (!result.success) {
				throw result.stderr;
			}
		});
		await executeChildProcess(["git", "--no-pager", "config", "--global", "filter.lfs.smudge", "git-lfs smudge --skip -- %f"]).then((result: ChildProcessResult): void => {
			if (!result.success) {
				throw result.stderr;
			}
		});
	} catch (error) {
		console.warn(`Unable to disable Git LFS process: ${error}`);
	}
}
interface GitGetCommitsIndexOptions {
	sortFromOldest?: boolean;
}
export async function getGitCommitMeta(index: string): Promise<GitCommitMeta | undefined> {
	for (let trial = 0; trial < 10; trial += 1) {
		const delimiter: string = crypto.randomUUID().replace(/-/gu, "");
		const result: ChildProcessResult = await executeChildProcess(["git", "--no-pager", "show", `--format=${gitCommitsProperties.map((property: GitCommitsProperty): string => {
			return property.placeholder;
		}).join(`%%${delimiter}%%`)}`, "--no-color", "--no-patch", index]);
		if (!result.success) {
			ghactionsError(`Unable to get Git commit meta ${index}: ${result.stderr}`);
			return undefined;
		}
		const raw: string[] = result.stdout.split(`%${delimiter}%`);
		if (raw.length !== gitCommitsProperties.length) {
			continue;
		}
		const gitCommitMeta: Partial<GitCommitMeta> = {};
		for (let row = 0; row < raw.length; row += 1) {
			const { name, transform } = gitCommitsProperties[row];
			const value: string = raw[row];
			//@ts-ignore Need to improve `gitCommitsProperties` to prevent this issue.
			gitCommitMeta[name] = (typeof transform === "undefined") ? value : transform(value);
		}
		return gitCommitMeta as GitCommitMeta;
	}
	ghactionsError(`Unable to get Git commit meta ${index}: Columns are not match!`);
	return undefined;
}
export async function getGitCommitsIndex({ sortFromOldest = false }: GitGetCommitsIndexOptions = {}): Promise<string[]> {
	const command: string[] = ["git", "--no-pager", "log", `--format=${gitCommitsPropertyIndexer.placeholder}`, "--no-color", "--all", "--reflog"];
	if (sortFromOldest) {
		command.push("--reverse");
	}
	const result: ChildProcessResult = await executeChildProcess(command);
	if (!result.success) {
		ghactionsError(`Unable to get Git commit index: ${result.stderr}`);
		return [];
	}
	return result.stdout.split(/\r?\n/gu);
}
export async function isGitRepository(): Promise<boolean> {
	const { stdout }: ChildProcessResult = await executeChildProcess(["git", "--no-pager", "rev-parse", "--is-inside-work-tree", "*>&1"]);
	return /^true$/iu.test(stdout);
}
