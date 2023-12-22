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
await executeChildProcess(["git", "--no-pager", "config", "--global", "--add", "safe.directory", cwd]).then((result: ChildProcessResult): void => {
	if (!result.success) {
		console.error(result.stderr);
		process.exit(result.code);
	}
});
export async function disableGitLFSProcess() {
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
