import { join as pathJoin } from "STD/path/join.ts";
import { pathAssetsRootAbsolute, pathAssetsRootName, pathProgramsVersionFileAbsolute, pathRoot } from "./lib/control.ts";
await new Deno.Command("git", {
	args: ["--no-pager", "clone", "--depth", "1", "https://github.com/hugoalh/scan-virus-ghaction-assets.git", pathAssetsRootName],
	cwd: pathRoot
}).output().then(({ code, stderr, success }: Deno.CommandOutput): void => {
	if (!success) {
		console.error(`Unable to import assets: ${new TextDecoder().decode(stderr)}`);
		Deno.exit(code);
	}
});
await new Deno.Command("git", { args: ["--no-pager", "config", "--global", "--add", "safe.directory", pathAssetsRootAbsolute] }).output().then(({ code, stderr, success }: Deno.CommandOutput): void => {
	if (!success) {
		console.error(`Unable to config Git: ${new TextDecoder().decode(stderr)}`);
		Deno.exit(code);
	}
});
async function printProgramVersion(command: string[], cwd?: string | URL): Promise<string> {
	const { code, stderr, stdout, success }: Deno.CommandOutput = await new Deno.Command(command[0], {
		args: command.slice(1),
		cwd
	}).output();
	if (!success) {
		console.error(`Unable to get program version: ${new TextDecoder().decode(stderr)}`);
		Deno.exit(code);
	}
	return new TextDecoder().decode(stdout);
}
const programsVersionMap: Map<string, string> = new Map<string, string>();
programsVersionMap.set("$Assets", await printProgramVersion(["git", "--no-pager", "log", "--format=%H", "--no-color"], pathAssetsRootAbsolute));
programsVersionMap.set("Deno", Deno.version.deno);
programsVersionMap.set("Git", await printProgramVersion(["git", "--no-pager", "--version"]));
programsVersionMap.set("Git LFS", await printProgramVersion(["git-lfs", "--version"]));
programsVersionMap.set("ClamAV Daemon", await printProgramVersion(["clamd", "--version"]));
programsVersionMap.set("ClamAV Scan Daemon", await printProgramVersion(["clamdscan", "--version"]));
programsVersionMap.set("ClamAV Scan", await printProgramVersion(["clamscan", "--version"]));
programsVersionMap.set("FreshClam", await printProgramVersion(["freshclam", "--version"]));
programsVersionMap.set("YARA", await printProgramVersion(["yara", "--version"]));
for (const fileName of [
	".git",
	".github",
	".gitattributes",
	".gitignore",
	"README.md",
	"updater.ps1"
]) {
	await Deno.remove(pathJoin(pathAssetsRootAbsolute, fileName), { recursive: true });
}
interface SVGHAProgramVersion {
	"Name": string;
	"Version": string;
}
const programsVersionTable: SVGHAProgramVersion[] = Array.from(programsVersionMap.entries(), ([Name, Version]: [string, string]): SVGHAProgramVersion => {
	return { Name, Version };
});
await Deno.writeTextFile(pathProgramsVersionFileAbsolute, JSON.stringify(programsVersionTable));
console.log("Programs Version: ");
console.table(programsVersionTable);
