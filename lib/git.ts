import { error as ghactionsError } from "GITHUB_ACTIONS_CORE";
import { cwd } from "./control.ts";
await new Deno.Command("git", { args: ["--no-pager", "config", "--global", "--add", "safe.directory", cwd] }).output().then(({ code, stderr, success }: Deno.CommandOutput): void => {
	if (!success) {
		console.error(`Unable to config Git: ${new TextDecoder().decode(stderr)}`);
		Deno.exit(code);
	}
});
interface GitCommitsPropertyMeta<T extends string | string[] | Date = string> {
	placeholder: `%${string}`;
	transform?: (item: string) => T;
}
interface GitCommitsProperties {
	authorDate: GitCommitsPropertyMeta<Date>;
	authorEmail: GitCommitsPropertyMeta;
	authorName: GitCommitsPropertyMeta;
	body: GitCommitsPropertyMeta;
	commitHash: GitCommitsPropertyMeta;
	committerDate: GitCommitsPropertyMeta<Date>;
	committerEmail: GitCommitsPropertyMeta;
	committerName: GitCommitsPropertyMeta;
	encoding: GitCommitsPropertyMeta;
	notes: GitCommitsPropertyMeta;
	parentHashes: GitCommitsPropertyMeta<string[]>;
	reflogIdentityEmail: GitCommitsPropertyMeta;
	reflogIdentityName: GitCommitsPropertyMeta;
	reflogSelector: GitCommitsPropertyMeta;
	reflogSubject: GitCommitsPropertyMeta;
	subject: GitCommitsPropertyMeta;
	treeHash: GitCommitsPropertyMeta;
}
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
const gitCommitsProperty: GitCommitsProperties = {
	authorDate: {
		placeholder: "%aI",
		transform: (item: string): Date => {
			return new Date(item);
		}
	},
	authorEmail: {
		placeholder: "%ae"
	},
	authorName: {
		placeholder: "%an"
	},
	body: {
		placeholder: "%b"
	},
	commitHash: {
		placeholder: "%H"
	},
	committerDate: {
		placeholder: "%cI",
		transform: (item: string): Date => {
			return new Date(item);
		}
	},
	committerEmail: {
		placeholder: "%ce"
	},
	committerName: {
		placeholder: "%cn"
	},
	encoding: {
		placeholder: "%e"
	},
	notes: {
		placeholder: "%N"
	},
	parentHashes: {
		placeholder: "%P",
		transform: (item: string): string[] => {
			return item.split(" ");
		}
	},
	reflogIdentityEmail: {
		placeholder: "%ge"
	},
	reflogIdentityName: {
		placeholder: "%gn"
	},
	reflogSelector: {
		placeholder: "%gD"
	},
	reflogSubject: {
		placeholder: "%gs"
	},
	subject: {
		placeholder: "%s"
	},
	treeHash: {
		placeholder: "%T"
	}
};
const gitCommitsPropertyIndexer = gitCommitsProperty.commitHash;
export async function disableGitLFSProcess(): Promise<void> {
	try {
		await new Deno.Command("git", { args: ["--no-pager", "config", "--global", "filter.lfs.process", "git-lfs filter-process --skip"] }).output().then(({ stderr, success }: Deno.CommandOutput): void => {
			if (!success) {
				throw (new TextDecoder().decode(stderr));
			}
		});
		await new Deno.Command("git", { args: ["--no-pager", "config", "--global", "filter.lfs.smudge", "git-lfs smudge --skip -- %f"] }).output().then(({ stderr, success }: Deno.CommandOutput): void => {
			if (!success) {
				throw (new TextDecoder().decode(stderr));
			}
		});
	} catch (error) {
		console.warn(`Unable to disable Git LFS process: ${error}`);
	}
}
export async function getGitCommitMeta(index: string): Promise<GitCommitMeta | undefined> {
	for (let trial = 0; trial < 10; trial += 1) {
		const delimiter: string = crypto.randomUUID().replace(/-/gu, "");
		const { stderr, stdout, success }: ChildProcessResult = await executeChildProcess(["git", "--no-pager", "show", `--format=${gitCommitsProperty.map((property: GitCommitsProperties): string => {
			return property.placeholder;
		}).join(`%%${delimiter}%%`)}`, "--no-color", "--no-patch", index]);
		if (!success) {
			ghactionsError(`Unable to get Git commit meta of ${index}: ${stderr}`);
			return undefined;
		}
		const raw: string[] = stdout.split(`%${delimiter}%`);
		if (raw.length !== gitCommitsProperty.length) {
			continue;
		}
		const gitCommitMeta: Partial<GitCommitMeta> = {};
		for (let row = 0; row < raw.length; row += 1) {
			const { name, transform } = gitCommitsProperty[row];
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
	sortFromOldest: boolean;
}
export async function getGitCommitsIndex(options: GitGetCommitsIndexOptions): Promise<string[]> {
	const { sortFromOldest }: GitGetCommitsIndexOptions = options;
	const args: string[] = ["--no-pager", "log", `--format=${gitCommitsPropertyIndexer.placeholder}`, "--no-color", "--all", "--reflog"];
	if (sortFromOldest) {
		args.push("--reverse");
	}
	const { stderr, stdout, success }: Deno.CommandOutput = await new Deno.Command("git", { args }).output();
	if (!success) {
		ghactionsError(`Unable to get Git commit index: ${new TextDecoder().decode(stderr)}`);
		return [];
	}
	return (new TextDecoder().decode(stdout).split(/\r?\n/gu));
}
export async function isGitRepository(): Promise<boolean> {
	const { stdout }: Deno.CommandOutput = await new Deno.Command("git", { args: ["--no-pager", "rev-parse", "--is-inside-work-tree", "*>&1"] }).output();
	return /^true$/iu.test(new TextDecoder().decode(stdout));
}
