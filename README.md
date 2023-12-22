# Scan Virus (GitHub Action)

[⚖️ MIT](./LICENSE.md)
[![CodeFactor Grade](https://img.shields.io/codefactor/grade/github/hugoalh/scan-virus-ghaction?label=Grade&logo=codefactor&logoColor=ffffff&style=flat-square "CodeFactor Grade")](https://www.codefactor.io/repository/github/hugoalh/scan-virus-ghaction)

|  | **Release - Latest** | **Release - Pre** |
|:-:|:-:|:-:|
| [![GitHub](https://img.shields.io/badge/GitHub-181717?logo=github&logoColor=ffffff&style=flat-square "GitHub")](https://github.com/hugoalh/scan-virus-ghaction) | ![GitHub Latest Release Version](https://img.shields.io/github/release/hugoalh/scan-virus-ghaction?sort=semver&label=&style=flat-square "GitHub Latest Release Version") (![GitHub Latest Release Date](https://img.shields.io/github/release-date/hugoalh/scan-virus-ghaction?label=&style=flat-square "GitHub Latest Release Date")) | ![GitHub Latest Pre-Release Version](https://img.shields.io/github/release/hugoalh/scan-virus-ghaction?include_prereleases&sort=semver&label=&style=flat-square "GitHub Latest Pre-Release Version") (![GitHub Latest Pre-Release Date](https://img.shields.io/github/release-date-pre/hugoalh/scan-virus-ghaction?label=&style=flat-square "GitHub Latest Pre-Release Date")) |

A GitHub Action to scan virus (including malicious file and malware).

> [!IMPORTANT]
> This documentation is v0.30.0 based; To view other version's documentation, please visit the [versions list](https://github.com/hugoalh/scan-virus-ghaction/tags) and select the correct version.

## 🌟 Feature

- 4\~96% faster than other GitHub Actions with the same purpose, especially when need to perform scan with multiple sessions.
- Ability to ignore specify paths, rules, sessions, and/or signatures.
- Ability to scan by every Git commits.
- Ability to use custom assets.
- Bundle with some of the communities' unofficial rules and signatures.

## 🛡️ Tools

- **`clamav`:** [ClamAV](https://www.clamav.net), made by [Cisco](https://www.cisco.com), is an open source anti virus engine for detecting trojans, viruses, malwares, and other malicious threats.
- **`yara`:** [YARA](http://virustotal.github.io/yara), made by [VirusTotal](https://www.virustotal.com), is a tool aimed at but not limited to help malware researchers to identify and classify malware samples.

### Unofficial Assets

Some of the communities have publicly published unofficial ClamAV and/or YARA assets for free. In order to adoptable, compatible, and usable with this action, these unofficial assets are stored in another repository [hugoalh/scan-virus-ghaction-assets](https://github.com/hugoalh/scan-virus-ghaction-assets).

## ⚠️ Disclaimer

This does not provide any guarantee that carefully hidden objects will be scanned. Strong endpoint security, access, and code review policies and practices are the most effective way to ensure that malicious files and/or codes are not introduced. False positives maybe also will be happened.

## 🔰 Begin

### GitHub Actions

- **Target Version:** >= v2.311.0, &:
  - Docker
- **Require Permission:** *N/A*

```yml
jobs:
  job_id:
    runs-on: "ubuntu-________"
    steps:
      - uses: "hugoalh/scan-virus-ghaction@<Tag>"
```

> [!NOTE]
> This action also provide editions of each tool:
>
> - **ClamAV:** `"hugoalh/scan-virus-ghaction/clamav@<Tag>"`
> - **YARA:** `"hugoalh/scan-virus-ghaction/yara@<Tag>"`

## 🧩 Input

> [!NOTE]
> All of the inputs are optional; Use this action without any input will default to:
>
> - **`@<Tag>`:** Scan with the ClamAV official assets.
> - **`/clamav@<Tag>`:** Scan with the ClamAV official assets.
> - **`/yara@<Tag>`:** Scan with the YARA unofficial assets.

### `clamav_enable`

`<boolean = true>` Whether to use ClamAV. When this is `false`, will ignore inputs:

- [`clamav_update`](#clamav_update)
- [`clamav_unofficialassets_use`](#clamav_unofficialassets_use)
- [`clamav_customassets_artifact`](#clamav_customassets_artifact)
- [`clamav_customassets_use`](#clamav_customassets_use)

### `clamav_update`

`<boolean = true>` Whether to update the ClamAV official assets before scan anything.

> [!IMPORTANT]
> It is recommended to keep this enable to have the latest ClamAV official assets.

### `clamav_unofficialassets_use`

`<RegExp[]>` ClamAV unofficial assets to use, by regular expression of names in the [ClamAV unofficial assets list](https://github.com/hugoalh/scan-virus-ghaction-assets/blob/main/clamav/index.tsv), separate each regular expression per line; By default, all of the ClamAV unofficial assets are not in use.

### `clamav_customassets_artifact`

`<string>` Artifact name of the ClamAV custom assets, which the artifact must uploaded before this action. When this is not defined, will ignore input [`clamav_customassets_use`](#clamav_customassets_use).

### `clamav_customassets_use`

`<RegExp[] = .+>` ClamAV custom assets to use, by regular expression of relative paths in the input [`clamav_customassets_artifact`](#clamav_customassets_artifact), separate each regular expression per line; By default, all of the ClamAV custom assets are in use.

### `yara_enable`

`<boolean = false>` Whether to use YARA. When this is `false`, will ignore inputs:

- [`yara_unofficialassets_use`](#yara_unofficialassets_use)
- [`yara_customassets_artifact`](#yara_customassets_artifact)
- [`yara_customassets_use`](#yara_customassets_use)

### `yara_unofficialassets_use`

`<RegExp[]>` YARA unofficial assets to use, by regular expression of names in the [YARA unofficial assets list](https://github.com/hugoalh/scan-virus-ghaction-assets/blob/main/yara/index.tsv), separate each regular expression per line; By default, all of the YARA unofficial assets are not in use.

### `yara_customassets_artifact`

`<string>` Artifact name of the YARA custom assets, which the artifact must uploaded before this action. When this is not defined, will ignore input [`yara_customassets_use`](#yara_customassets_use).

### `yara_customassets_use`

`<RegExp[] = .+>` YARA custom assets to use, by regular expression of relative paths in the input [`yara_customassets_artifact`](#yara_customassets_artifact), separate each regular expression per line; By default, all of the YARA custom assets are in use.

### `git_integrate`

`<boolean = false>` Whether to integrate with Git to perform scan by every commits; Require directory is a Git repository. When this is `false`, will ignore inputs:

- [`git_ignores`](#git_ignores)
- [`git_lfs`](#git_lfs)
- [`git_limit`](#git_limit)
- [`git_reverse`](#git_reverse)

### `git_ignores`

`<function>` Ignores by the Git commits, by JavaScript function and must return type of `boolean` (only return `true` to able ignore). Ignored Git commits will not be scanned.

```ts
({ ... }: {
  authorDate: Date;
  authorEmail: string;
  authorName: string;
  body: string;
  commitHash: string;
  committerDate: Date;
  committerEmail: string;
  committerName: string;
  encoding: string;
  notes: string;
  parentHashes: string[];
  reflogIdentityEmail: string;
  reflogIdentityName: string;
  reflogSelector: string;
  reflogSubject: string;
  subject: string;
  treeHash: string;
}) => {
  /* ... Code for determine ... */
  return result;
}
```

> [!NOTE]
> It is TypeScript syntax at the above in order to show the type of the parameters; But remember to use JavaScript syntax for this input.

For example, to ignore Git commits made by Dependabot, and ignore Git commits made by OctoCat before 2022-01-01:

```yml
git_ignores: |-
  ({ authorDate, authorName }) => {
    return (
      /^dependabot/iu.test(authorName) ||
      (authorDate.valueOf() < new Date("2022-01-01T00:00:00Z").valueOf() && /^octocat$/iu.test(authorName))
    );
  }
```

> [!CAUTION]
> JavaScript function is extremely powerful, which also able to execute malicious actions, user should always take extra review for this input value.

### `git_lfs`

`<boolean = false>` Whether to process Git LFS files.

### `git_limit`

`<bigint = 0>` Limit on how many Git commits will scan, counting is affected by inputs [`git_ignores`](#git_ignores) and [`git_reverse`](#git_reverse); When this value is `0`, means no limit.

> [!IMPORTANT]
> For actions which run on the GitHub-host, it is highly recommended to define this due to the limit of the job execution time (currently is `6 hours`).

### `git_reverse`

`<boolean = false>` Whether to reverse the scan order of the Git commits.

- **`false`:** From the newest commit to the oldest commit.
- **`true`:** From the oldest commit to the newest commit.

### `ignores_pre`

`<function>` Ignores by the paths, sessions, and tools before the scan, by JavaScript function and must return type of `boolean` (only return `true` to able ignore).

To ignore only by the Git commits, use input [`git_ignores`](#git_ignores) is more efficiency. To ignore only by the tools, use inputs `*_enable` is more efficiency.

```ts
({ ... }: {
  /** Relative path based on the current working directory without `./` (e.g.: `relative/path/to/file.extension`). */
  path: string;
  session: {
    /** "Current" or Git commit hash. */
    name: string;
    /** Git commit meta, only exists when the session is on a Git commit. */
    gitCommitMeta?: {
      authorDate: Date;
      authorEmail: string;
      authorName: string;
      body: string;
      commitHash: string;
      committerDate: Date;
      committerEmail: string;
      committerName: string;
      encoding: string;
      notes: string;
      parentHashes: string[];
      reflogIdentityEmail: string;
      reflogIdentityName: string;
      reflogSelector: string;
      reflogSubject: string;
      subject: string;
      treeHash: string;
    };
  };
  /** Tool ID. */
  tool: string;
}) => {
  /* ... Code for determine ... */
  return result;
}
```

> [!NOTE]
> It is TypeScript syntax at the above in order to show the type of the parameters; But remember to use JavaScript syntax for this input.

For example, to ignore path `node_modules`:

```yml
ignores_pre: |-
  ({ path }) => {
    return /^node_modules[\\\/]/u.test(path);
  }
```

> [!CAUTION]
> JavaScript function is extremely powerful, which also able to execute malicious actions, user should always take extra review for this input value.

### `ignores_post`

`<function>` Ignores by the paths, sessions, symbols (i.e. rules or signatures), and tools after the scan, by JavaScript function and must return type of `boolean` (only return `true` to able ignore).

To ignore only by the paths and/or sessions, use input [`ignores_pre`](#ignores_pre) is more efficiency. To ignore only by the Git commits, use input [`git_ignores`](#git_ignores) is more efficiency. To ignore only by the tools, use inputs `*_enable` is more efficiency.

```ts
({ ... }: {
  /** Relative path based on the current working directory without `./` (e.g.: `relative/path/to/file.extension`). */
  path: string;
  session: {
    /** "Current" or Git commit hash. */
    name: string;
    /** Git commit meta, only exists when the session is on a Git commit. */
    gitCommitMeta?: {
      authorDate: Date;
      authorEmail: string;
      authorName: string;
      body: string;
      commitHash: string;
      committerDate: Date;
      committerEmail: string;
      committerName: string;
      encoding: string;
      notes: string;
      parentHashes: string[];
      reflogIdentityEmail: string;
      reflogIdentityName: string;
      reflogSelector: string;
      reflogSubject: string;
      subject: string;
      treeHash: string;
    };
  };
  /** Rule or signature. */
  symbol: string;
  /** Tool ID. */
  tool: string;
}) => {
  /* ... Code for determine ... */
  return result;
}
```

> [!NOTE]
> It is TypeScript syntax at the above in order to show the type of the parameters; But remember to use JavaScript syntax for this input.

> [!CAUTION]
> It is not recommended to ignore any official symbol due to these rarely have false positives in most cases.

> [!CAUTION]
> JavaScript function is extremely powerful, which also able to execute malicious actions, user should always take extra review for this input value.

### `summary`

`<boolean = false>` Whether to generate summary.

## 🧩 Output

### `finish`

`<boolean>` Whether this action correctly finished without non catch issues.

### `found`

`<boolean>` Whether there has element which found virus.

## ✍️ Example

- ```yml
  jobs:
    job_id:
      name: "Scan Virus"
      runs-on: "ubuntu-latest"
      steps:
        - name: "Checkout Repository"
          uses: "actions/checkout@v4.0.0"
          with:
            fetch-depth: 0
        - name: "Scan Repository"
          uses: "hugoalh/scan-virus-ghaction@v0.20.0"
          with:
            git_ignores: |-
              ({ authorDate, authorName }) => {
                return (
                  /^dependabot/iu.test(authorName) ||
                  (authorDate.valueOf() < new Date("2022-01-01T00:00:00Z").valueOf() && /^octocat$/iu.test(authorName))
                );
              }
            git_limit: 100
            ignores_pre: |-
              ({ path }) => {
                return /^node_modules[\\\/]/u.test(path);
              }
  ```

## 📚 Guide

- GitHub Actions
  - [Enabling debug logging](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/enabling-debug-logging)
