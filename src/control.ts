import escapeStringRegExp from "escape-string-regexp";
export const cwd: string = process.cwd();
export const patternCWD: string = escapeStringRegExp(cwd);
export const toolForce: string | undefined = process.env.SVGHA_TOOLFORCE;
