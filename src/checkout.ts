import { rm as fsRm, writeFile as fsWriteFile } from "node:fs/promises";
import { join as pathJoin } from "node:path";
import { toolForce } from "./control.js";
import { executeChildProcess, type ChildProcessResult } from "./execute.js";
async function getProgramVersion(...inputs: Parameters<typeof executeChildProcess>): Promise<string> {
	const result: ChildProcessResult = await executeChildProcess(...inputs);
	if (!result.success) {
		console.error(result.stderr);
		process.exit(result.code);
	}
	return result.stdout;
}
console.log("Import assets.");
await executeChildProcess(["git", "--no-pager", "clone", "--depth", "1", "https://github.com/hugoalh/scan-virus-ghaction-assets.git", "assets"], { cwd: process.env.SVGHA_ROOT }).then((result: ChildProcessResult): void => {
	if (!result.success) {
		console.error(result.stderr);
		process.exit(result.code);
	}
});
await executeChildProcess(["git", "--no-pager", "config", "--global", "--add", "safe.directory", process.env.SVGHA_ASSETS_ROOT]).then((result: ChildProcessResult): void => {
	if (!result.success) {
		console.error(result.stderr);
		process.exit(result.code);
	}
});
const programsVersionTable: Record<string, string> = {};
programsVersionTable["NodeJS"] = process.versions.node;
programsVersionTable["Git"] = await getProgramVersion(["git", "--no-pager", "--version"]);
programsVersionTable["Git LFS"] = await getProgramVersion(["git-lfs", "--version"]);
programsVersionTable["$Assets"] = await getProgramVersion(["git", "--no-pager", "log", "--format=%H", "--no-color"], { cwd: process.env.SVGHA_ASSETS_ROOT });
for (const fileName of [
	".git",
	".github",
	".gitattributes",
	".gitignore",
	"README.md",
	"updater.ps1"
]) {
	await fsRm(pathJoin(process.env.SVGHA_ASSETS_ROOT, fileName));
}
if (
	typeof toolForce === "undefined" ||
	toolForce === "clamav"
) {
	programsVersionTable["ClamAV Daemon"] = await getProgramVersion(["clamd", "--version"]);
	programsVersionTable["ClamAV Scan Daemon"] = await getProgramVersion(["clamdscan", "--version"]);
	programsVersionTable["ClamAV Scan"] = await getProgramVersion(["clamscan", "--version"]);
	programsVersionTable["FreshClam"] = await getProgramVersion(["freshclam", "--version"]);
} else {
	await fsRm(process.env.SVGHA_ASSETS_CLAMAV, {
		maxRetries: 9,
		recursive: true
	});
}
if (
	typeof toolForce === "undefined" ||
	toolForce === "yara"
) {
	programsVersionTable["YARA"] = await getProgramVersion(["yara", "--version"]);
} else {
	await fsRm(process.env.SVGHA_ASSETS_YARA, {
		maxRetries: 9,
		recursive: true
	});
}
await fsWriteFile(process.env.SVGHA_PROGRAMSVERSIONFILE, JSON.stringify(programsVersionTable), { encoding: "utf-8" });
console.log("Programs Version: ");
console.table(Object.entries(programsVersionTable));
