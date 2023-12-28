import { rm as fsRm, writeFile as fsWriteFile } from "node:fs/promises";
import { join as pathJoin } from "node:path";
import { toolKit } from "./control.js";
import { executeChildProcess, type ChildProcessResult } from "./execute.js";
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
async function getProgramVersion(...inputs: Parameters<typeof executeChildProcess>): Promise<string> {
	const result: ChildProcessResult = await executeChildProcess(...inputs);
	if (!result.success) {
		console.error(result.stderr);
		process.exit(result.code);
	}
	return result.stdout;
}
const programsVersionMap: Map<string, string> = new Map<string, string>();
programsVersionMap.set("NodeJS", process.versions.node);
programsVersionMap.set("Git", await getProgramVersion(["git", "--no-pager", "--version"]));
programsVersionMap.set("Git LFS", await getProgramVersion(["git-lfs", "--version"]));
programsVersionMap.set("$Assets", await getProgramVersion(["git", "--no-pager", "log", "--format=%H", "--no-color"], { cwd: process.env.SVGHA_ASSETS_ROOT }));
await Promise.all([
	".git",
	".github",
	".gitattributes",
	".gitignore",
	"README.md",
	"updater.ps1"
].map((fileName: string): Promise<void> => {
	return fsRm(pathJoin(process.env.SVGHA_ASSETS_ROOT, fileName), {
		maxRetries: 9,
		recursive: true,
		retryDelay: 1000
	});
}));
if (
	toolKit === "*" ||
	toolKit === "clamav"
) {
	programsVersionMap.set("ClamAV Daemon", await getProgramVersion(["clamd", "--version"]));
	programsVersionMap.set("ClamAV Scan Daemon", await getProgramVersion(["clamdscan", "--version"]));
	programsVersionMap.set("ClamAV Scan", await getProgramVersion(["clamscan", "--version"]));
	programsVersionMap.set("FreshClam", await getProgramVersion(["freshclam", "--version"]));
} else {
	await fsRm(process.env.SVGHA_ASSETS_CLAMAV, {
		maxRetries: 9,
		recursive: true,
		retryDelay: 1000
	});
}
if (
	toolKit === "*" ||
	toolKit === "yara"
) {
	programsVersionMap.set("YARA", await getProgramVersion(["yara", "--version"]));
} else {
	await fsRm(process.env.SVGHA_ASSETS_YARA, {
		maxRetries: 9,
		recursive: true,
		retryDelay: 1000
	});
}
interface ScanVirusGitHubActionProgramVersion {
	"Name": string;
	"Version": string;
}
const programsVersionTable: ScanVirusGitHubActionProgramVersion[] = Array.from(programsVersionMap.entries(), ([name, version]: [string, string]): ScanVirusGitHubActionProgramVersion => {
	return {
		Name: name,
		Version: version
	};
});
await fsWriteFile(process.env.SVGHA_PROGRAMSVERSIONFILE, JSON.stringify(programsVersionTable), { encoding: "utf-8" });
console.log("Programs Version: ");
console.table(programsVersionTable);
