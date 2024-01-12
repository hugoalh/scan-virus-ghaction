import { rm as fsRm, writeFile } from "node:fs/promises";
import { join as pathJoin } from "node:path";
import { pathAssetsRootAbsolute, pathAssetsRootName, pathProgramsVersionFileAbsolute, pathRoot, toolkit } from "./control.js";
import { executeChildProcess, type ChildProcessResult } from "./execute-child-process.js";
async function getProgramVersion(...inputs: Parameters<typeof executeChildProcess>): Promise<string> {
	const { code, stderr, stdout, success }: ChildProcessResult = await executeChildProcess(...inputs);
	if (!success) {
		console.error(`Unable to get program version: ${stderr}`);
		process.exit(code);
	}
	return stdout;
}
await executeChildProcess(["git", "--no-pager", "clone", "--depth", "1", "https://github.com/hugoalh/scan-virus-ghaction-assets.git", pathAssetsRootName], { cwd: pathRoot }).then(({ code, stderr, success }: ChildProcessResult): void => {
	if (!success) {
		console.error(`Unable to import assets: ${stderr}`);
		process.exit(code);
	}
});
await executeChildProcess(["git", "--no-pager", "config", "--global", "--add", "safe.directory", pathAssetsRootAbsolute]).then(({ code, stderr, success }: ChildProcessResult): void => {
	if (!success) {
		console.error(`Unable to config Git: ${stderr}`);
		process.exit(code);
	}
});
const programsVersionMap: Map<string, string> = new Map<string, string>();
programsVersionMap.set("NodeJS", process.versions.node);
programsVersionMap.set("Git", await getProgramVersion(["git", "--no-pager", "--version"]));
programsVersionMap.set("Git LFS", await getProgramVersion(["git-lfs", "--version"]));
programsVersionMap.set("$Assets", await getProgramVersion(["git", "--no-pager", "log", "--format=%H", "--no-color"], { cwd: pathAssetsRootAbsolute }));
[
	".git",
	".github",
	".gitattributes",
	".gitignore",
	"README.md",
	"updater.ps1"
].forEach((fileName: string): void => {
	fsRm(pathJoin(pathAssetsRootAbsolute, fileName), {
		maxRetries: 9,
		recursive: true,
		retryDelay: 1000
	});
});
if (
	toolkit === "*" ||
	toolkit === "clamav"
) {
	programsVersionMap.set("ClamAV Daemon", await getProgramVersion(["clamd", "--version"]));
	programsVersionMap.set("ClamAV Scan Daemon", await getProgramVersion(["clamdscan", "--version"]));
	programsVersionMap.set("ClamAV Scan", await getProgramVersion(["clamscan", "--version"]));
	programsVersionMap.set("FreshClam", await getProgramVersion(["freshclam", "--version"]));
} else {
	fsRm(pathJoin(pathAssetsRootAbsolute, "clamav"), {
		maxRetries: 9,
		recursive: true,
		retryDelay: 1000
	});
}
if (
	toolkit === "*" ||
	toolkit === "yara"
) {
	programsVersionMap.set("YARA", await getProgramVersion(["yara", "--version"]));
} else {
	fsRm(pathJoin(pathAssetsRootAbsolute, "yara"), {
		maxRetries: 9,
		recursive: true,
		retryDelay: 1000
	});
}
interface SVGHAProgramVersion {
	"Name": string;
	"Version": string;
}
const programsVersionTable: SVGHAProgramVersion[] = Array.from(programsVersionMap.entries(), ([Name, Version]: [string, string]): SVGHAProgramVersion => {
	return { Name, Version };
});
writeFile(pathProgramsVersionFileAbsolute, JSON.stringify(programsVersionTable), { encoding: "utf-8" });
console.log("Programs Version: ");
console.table(programsVersionTable);
