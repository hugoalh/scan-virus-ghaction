import { error as ghactionsError } from "@actions/core";
import { cwd } from "./control.js";
import { executeChildProcess } from "./execute-child-process.js";
await executeChildProcess(["git", "--no-pager", "config", "--global", "--add", "safe.directory", cwd]).then(({ code, stderr, success }) => {
    if (!success) {
        console.error(`Unable to config Git: ${stderr}`);
        process.exit(code);
    }
});
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
const gitCommitsPropertyIndexer = gitCommitsProperties.filter(({ asIndex = false }) => {
    return asIndex;
})[0];
export async function disableGitLFSProcess() {
    try {
        await executeChildProcess(["git", "--no-pager", "config", "--global", "filter.lfs.process", "git-lfs filter-process --skip"]).then(({ stderr, success }) => {
            if (!success) {
                throw stderr;
            }
        });
        await executeChildProcess(["git", "--no-pager", "config", "--global", "filter.lfs.smudge", "git-lfs smudge --skip -- %f"]).then(({ stderr, success }) => {
            if (!success) {
                throw stderr;
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
        const { stderr, stdout, success } = await executeChildProcess(["git", "--no-pager", "show", `--format=${gitCommitsProperties.map((property) => {
                return property.placeholder;
            }).join(`%%${delimiter}%%`)}`, "--no-color", "--no-patch", index]);
        if (!success) {
            ghactionsError(`Unable to get Git commit meta of ${index}: ${stderr}`);
            return undefined;
        }
        const raw = stdout.split(`%${delimiter}%`);
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
    ghactionsError(`Unable to get Git commit meta of ${index}: Columns are not match!`);
    return undefined;
}
export async function getGitCommitsIndex({ sortFromOldest = false } = {}) {
    const command = ["git", "--no-pager", "log", `--format=${gitCommitsPropertyIndexer.placeholder}`, "--no-color", "--all", "--reflog"];
    if (sortFromOldest) {
        command.push("--reverse");
    }
    const { stderr, stdout, success } = await executeChildProcess(command);
    if (!success) {
        ghactionsError(`Unable to get Git commit index: ${stderr}`);
        return [];
    }
    return stdout.split(/\r?\n/gu);
}
export async function isGitRepository() {
    const { stdout } = await executeChildProcess(["git", "--no-pager", "rev-parse", "--is-inside-work-tree", "*>&1"]);
    return /^true$/iu.test(stdout);
}
