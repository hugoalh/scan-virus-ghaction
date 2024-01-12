import { spawn } from "node:child_process";
/**
 * Execute child process.
 * @param {string[]} command Command.
 * @param {Parameters<typeof spawn>[2]} [options={}] Options.
 * @returns {Promise<ChildProcessResult>} Result.
 */
export function executeChildProcess(command, options = {}) {
    return new Promise((resolve) => {
        const cp = spawn(command[0], command.slice(1), options);
        let stderr = "";
        let stdout = "";
        cp.stderr.on("data", (chunk) => {
            stderr += chunk;
        });
        cp.stdout.on("data", (chunk) => {
            stdout += chunk;
        });
        cp.on("close", (code) => {
            resolve({
                code,
                stderr,
                stdout,
                success: code === 0
            });
        });
    });
}
