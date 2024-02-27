import { join as pathJoin } from "STD/path/join.ts";
import { escape as escapeStringRegExp } from "STD/regexp/escape.ts";
export const pathRoot: string = ((): string => {
	const value: string | undefined = Deno.env.get("SVGHA_ROOT");
	if (typeof value === "undefined") {
		throw new ReferenceError(`Environment variable \`SVGHA_ROOT\` is not defined!`);
	}
	return value;
})();
export const pathAssetsRootName = "assets";
export const pathAssetsRootAbsolute: string = pathJoin(pathRoot, pathAssetsRootName);
export const pathProgramsVersionFileName = "programs-version.json";
export const pathProgramsVersionFileAbsolute: string = pathJoin(pathRoot, pathProgramsVersionFileName);
export const cwd: string = Deno.cwd();
export const patternCWD: string = escapeStringRegExp(cwd);
