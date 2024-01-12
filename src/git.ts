import { error as ghactionsError } from "@actions/core";
import { cwd } from "./control.js";
import { executeChildProcess, type ChildProcessResult } from "./execute-child-process.js";
await executeChildProcess(["git", "--no-pager", "config", "--global", "--add", "safe.directory", cwd]).then(({ code, stderr, success }: ChildProcessResult): void => {
	if (!success) {
		console.error(`Unable to config Git: ${stderr}`);
		process.exit(code);
	}
});
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
	transform?: (item: string) => GitCommitMeta[this["name"]];
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
const gitCommitsPropertyIndexer: GitCommitsProperty = gitCommitsProperties.filter(({ asIndex = false }: GitCommitsProperty): boolean => {
	return asIndex;
})[0];
export async function disableGitLFSProcess(): Promise<void> {
	try {
		await executeChildProcess(["git", "--no-pager", "config", "--global", "filter.lfs.process", "git-lfs filter-process --skip"]).then(({ stderr, success }: ChildProcessResult): void => {
			if (!success) {
				throw stderr;
			}
		});
		await executeChildProcess(["git", "--no-pager", "config", "--global", "filter.lfs.smudge", "git-lfs smudge --skip -- %f"]).then(({ stderr, success }: ChildProcessResult): void => {
			if (!success) {
				throw stderr;
			}
		});
	} catch (error) {
		console.warn(`Unable to disable Git LFS process: ${error}`);
	}
}
export async function getGitCommitMeta(index: string): Promise<GitCommitMeta | undefined> {
	for (let trial = 0; trial < 10; trial += 1) {
		const delimiter: string = crypto.randomUUID().replace(/-/gu, "");
		const { stderr, stdout, success }: ChildProcessResult = await executeChildProcess(["git", "--no-pager", "show", `--format=${gitCommitsProperties.map((property: GitCommitsProperty): string => {
			return property.placeholder;
		}).join(`%%${delimiter}%%`)}`, "--no-color", "--no-patch", index]);
		if (!success) {
			ghactionsError(`Unable to get Git commit meta of ${index}: ${stderr}`);
			return undefined;
		}
		const raw: string[] = stdout.split(`%${delimiter}%`);
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
	ghactionsError(`Unable to get Git commit meta of ${index}: Columns are not match!`);
	return undefined;
}
interface GitGetCommitsIndexOptions {
	sortFromOldest?: boolean;
}
export async function getGitCommitsIndex({ sortFromOldest = false }: GitGetCommitsIndexOptions = {}): Promise<string[]> {
	const command: string[] = ["git", "--no-pager", "log", `--format=${gitCommitsPropertyIndexer.placeholder}`, "--no-color", "--all", "--reflog"];
	if (sortFromOldest) {
		command.push("--reverse");
	}
	const { stderr, stdout, success }: ChildProcessResult = await executeChildProcess(command);
	if (!success) {
		ghactionsError(`Unable to get Git commit index: ${stderr}`);
		return [];
	}
	return stdout.split(/\r?\n/gu);
}
export async function isGitRepository(): Promise<boolean> {
	const { stdout }: ChildProcessResult = await executeChildProcess(["git", "--no-pager", "rev-parse", "--is-inside-work-tree", "*>&1"]);
	return /^true$/iu.test(stdout);
}
