import { execSync } from "node:child_process";
import { mkdir as fsMkDir, readdir as fsReadDir, rm as fsRm, writeFile as fsWriteFile } from "node:fs/promises";
import { dirname as pathDirname, join as pathJoin } from "node:path";
import { fileURLToPath } from "node:url";
import ncc from "@vercel/ncc";
const workspace = pathDirname(fileURLToPath(import.meta.url));
const directoryInput = pathJoin(workspace, "temp");
const directoryOutput = pathJoin(workspace, "dist");
const scriptsFilename = new Set([
	"pre.js",
	"main.js",
	"post.js"
]);

/* Initialize output directory. */
await fsMkDir(directoryOutput, { recursive: true });
for (const fileName of await fsReadDir(directoryOutput)) {
	await fsRm(pathJoin(directoryOutput, fileName), { recursive: true }).catch((reason) => {
		console.warn(reason);
	});
}

/* Create bundle. */
console.log(execSync(`"${pathJoin(workspace, "node_modules", ".bin", process.platform === "win32" ? "tsc.cmd" : "tsc")}" -p "${pathJoin(workspace, "tsconfig.json")}"`).toString("utf8"));
for (const scriptFilename of scriptsFilename) {
	const { code } = await ncc(pathJoin(directoryInput, scriptFilename), {
		assetBuilds: false,
		cache: false,
		debugLog: false,
		license: "",
		minify: true,
		quiet: false,
		sourceMap: false,
		sourceMapRegister: false,
		target: "es2022",
		v8cache: false,
		watch: false
	});
	await fsWriteFile(pathJoin(directoryOutput, scriptFilename), code, { encoding: "utf8" });
}
