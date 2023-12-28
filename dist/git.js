import { error as ghactionsError } from "@actions/core";
import { cwd } from "./control.js";
import { executeChildProcess } from "./execute.js";
const gitCommitsProperties = [
    {
        name: "authorDate",
        placeholder: "%aI",
        transform: (item) => {
            return new Date(item);
        }
    },
    {
        name: "authorEmail",
        placeholder: "%ae"
    },
    {
        name: "authorName",
        placeholder: "%an"
    },
    {
        name: "body",
        placeholder: "%b"
    },
    {
        asIndex: true,
        name: "commitHash",
        placeholder: "%H"
    },
    {
        name: "committerDate",
        placeholder: "%cI",
        transform: (item) => {
            return new Date(item);
        }
    },
    {
        name: "committerEmail",
        placeholder: "%ce"
    },
    {
        name: "committerName",
        placeholder: "%cn"
    },
    {
        name: "encoding",
        placeholder: "%e"
    },
    {
        name: "notes",
        placeholder: "%N"
    },
    {
        name: "parentHashes",
        placeholder: "%P",
        transform: (item) => {
            return item.split(" ");
        }
    },
    {
        name: "reflogIdentityEmail",
        placeholder: "%ge"
    },
    {
        name: "reflogIdentityName",
        placeholder: "%gn"
    },
    {
        name: "reflogSelector",
        placeholder: "%gD"
    },
    {
        name: "reflogSubject",
        placeholder: "%gs"
    },
    {
        name: "subject",
        placeholder: "%s"
    },
    {
        name: "treeHash",
        placeholder: "%T"
    }
];
const gitCommitsPropertyIndexer = gitCommitsProperties.filter((property) => {
    return property.asIndex ?? false;
})[0];
await executeChildProcess(["git", "--no-pager", "config", "--global", "--add", "safe.directory", cwd]).then((result) => {
    if (!result.success) {
        console.error(result.stderr);
        process.exit(result.code);
    }
});
export async function disableGitLFSProcess() {
    try {
        await executeChildProcess(["git", "--no-pager", "config", "--global", "filter.lfs.process", "git-lfs filter-process --skip"]).then((result) => {
            if (!result.success) {
                throw result.stderr;
            }
        });
        await executeChildProcess(["git", "--no-pager", "config", "--global", "filter.lfs.smudge", "git-lfs smudge --skip -- %f"]).then((result) => {
            if (!result.success) {
                throw result.stderr;
            }
        });
    }
    catch (error) {
        console.warn(`Unable to disable Git LFS process: ${error}`);
    }
}
export async function getGitCommitMeta(index) {
    for (let trial = 0; trial < 10; trial += 1) {
        const delimiter = crypto.randomUUID().replace(/-/gu, "");
        const result = await executeChildProcess(["git", "--no-pager", "show", `--format=${gitCommitsProperties.map((property) => {
                return property.placeholder;
            }).join(`%%${delimiter}%%`)}`, "--no-color", "--no-patch", index]);
        if (!result.success) {
            ghactionsError(`Unable to get Git commit meta ${index}: ${result.stderr}`);
            return undefined;
        }
        const raw = result.stdout.split(`%${delimiter}%`);
        if (raw.length !== gitCommitsProperties.length) {
            continue;
        }
        const gitCommitMeta = {};
        for (let row = 0; row < raw.length; row += 1) {
            const { name, transform } = gitCommitsProperties[row];
            const value = raw[row];
            //@ts-ignore Need to improve `gitCommitsProperties` to prevent this issue.
            gitCommitMeta[name] = (typeof transform === "undefined") ? value : transform(value);
        }
        return gitCommitMeta;
    }
}
export async function getGitCommitsIndex({ sortFromOldest = false } = {}) {
    const command = ["git", "--no-pager", "log", `--format=${gitCommitsPropertyIndexer.placeholder}`, "--no-color", "--all", "--reflog"];
    if (sortFromOldest) {
        command.push("--reverse");
    }
    const result = await executeChildProcess(command);
    if (!result.success) {
        ghactionsError(`Unable to get Git commit index: ${result.stderr}`);
        return [];
    }
    return result.stdout.split(/\r?\n/gu);
}
export async function isGitRepository() {
    const result = await executeChildProcess(["git", "--no-pager", "rev-parse", "--is-inside-work-tree", "*>&1"]);
    if (!result.success) {
        throw new Error(`Unable to integrate with Git: ${result.stderr}`);
    }
    return /^true$/iu.test(result.stdout);
}
