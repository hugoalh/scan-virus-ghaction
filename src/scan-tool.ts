import { rm as fsRm, writeFile } from "node:fs/promises";
import { tmpdir as osTmpdir } from "node:os";
import { isAbsolute as pathIsAbsolute, join as pathJoin } from "node:path";
import { cwd, patternCWD } from "./control.js";
import { executeChildProcess, type ChildProcessResult } from "./execute-child-process.js";
const clamavAssetsAllowExtensions: Set<string> = new Set<string>([
	"*.cat",
	"*.cbc",
	"*.cdb",
	"*.crb",
	"*.fp",
	"*.ftm",
	"*.gdb",
	"*.hdb",
	"*.hdu",
	"*.hsb",
	"*.hsu",
	"*.idb",
	"*.ign",
	"*.ign2",
	"*.info",
	"*.ldb",
	"*.ldu",
	"*.mdb",
	"*.mdu",
	"*.msb",
	"*.msu",
	"*.ndb",
	"*.ndu",
	"*.pdb",
	"*.pwdb",
	"*.sfp",
	"*.wdb",
	"*.yar",
	"*.yara"
]);
export interface SVGHAScanToolFound {
	path: string;
	symbol: string;
}
export async function executeClamAVScan(items: string[]) {
	const scanListFileAbsolutePath: string = pathJoin(osTmpdir(), crypto.randomUUID());
	await writeFile(scanListFileAbsolutePath, items.map((item: string): string => {
		return pathIsAbsolute(item) ? item : pathJoin(cwd, item);
	}).join("\n"), { encoding: "utf-8" });
	const { stdout }: ChildProcessResult = await executeChildProcess(["clamdscan", "--fdpass", `--file-list=${scanListFileAbsolutePath}`, "--multiscan", "*>&1"]);
	fsRm(scanListFileAbsolutePath).catch((reason: unknown): void => {
		console.warn(`Unable to remove file \`${scanListFileAbsolutePath}\`: ${reason}\nThis is fine, but maybe cause stack issue in the future.`);
	});
	const founds: SVGHAScanToolFound[] = [];
	const issues: string[] = [];
	for (const row of stdout.split(/\r?\n/gu).map((_: string): string => {
		return _.replace(new RegExp(`^${patternCWD}[\\\\\\/]`, "u"), "");
	})) {
		if (/^[-=]+\s*SCAN SUMMARY\s*[-=]+$/u.test(row)) {
			break;
		}
		if (
			/: OK$/u.test(row) ||
			/^\s*$/u.test(row)
		) {
			continue;
		}
		if (/: .+ FOUND$/u.test(row)) {
			const [path, symbol] = row.replace(/ FOUND$/u, "").split(/(?<=^.+?): /u);
			founds.push({ path, symbol });
			continue;
		}
		if (row.length > 0) {
			issues.push(row);
			continue;
		}
	}
	return { founds, issues };
}
