import { ChildProcess, spawn } from "node:child_process";
export interface ChildProcessResult {
	/**
	 * Exit code of the process.
	 */
	code: number;
	/**
	 * The `stderr` from the process.
	 */
	stderr: string;
	/**
	 * The `stdout` from the process.
	 */
	stdout: string;
	/**
	 * Whether the process exits with code `0`.
	 */
	success: boolean;
}
/**
 * Execute child process.
 * @param {string[]} command Command.
 * @param {Parameters<typeof spawn>[2]} [options={}] Options.
 * @returns {Promise<ChildProcessResult>} Result.
 */
export function executeChildProcess(command: string[], options: Parameters<typeof spawn>[2] = {}): Promise<ChildProcessResult> {
	return new Promise((resolve: (value: ChildProcessResult) => void): void => {
		const cp: ChildProcess = spawn(command[0], command.slice(1), options);
		let stderr = "";
		let stdout = "";
		cp.stderr.on("data", (chunk: string): void => {
			stderr += chunk;
		});
		cp.stdout.on("data", (chunk: string): void => {
			stdout += chunk;
		});
		cp.on("close", (code: number): void => {
			resolve({
				code,
				stderr,
				stdout,
				success: code === 0
			});
		});
	});
}
