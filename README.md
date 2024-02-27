# Scan Virus (GitHub Action)

[⚖️ MIT](./LICENSE.md)

|  | **Release - Latest** | **Release - Pre** |
|:-:|:-:|:-:|
| [![GitHub](https://img.shields.io/badge/GitHub-181717?logo=github&logoColor=ffffff&style=flat-square "GitHub")](https://github.com/hugoalh/scan-virus-ghaction) | ![GitHub Latest Release Version](https://img.shields.io/github/release/hugoalh/scan-virus-ghaction?sort=semver&label=&style=flat-square "GitHub Latest Release Version") (![GitHub Latest Release Date](https://img.shields.io/github/release-date/hugoalh/scan-virus-ghaction?label=&style=flat-square "GitHub Latest Release Date")) | ![GitHub Latest Pre-Release Version](https://img.shields.io/github/release/hugoalh/scan-virus-ghaction?include_prereleases&sort=semver&label=&style=flat-square "GitHub Latest Pre-Release Version") (![GitHub Latest Pre-Release Date](https://img.shields.io/github/release-date-pre/hugoalh/scan-virus-ghaction?label=&style=flat-square "GitHub Latest Pre-Release Date")) |

A GitHub Action to scan virus (including malicious file and malware).

> [!IMPORTANT]
> This documentation is v0.30.0 based; To view other version's documentation, please visit the [versions list](https://github.com/hugoalh/scan-virus-ghaction/tags) and select the correct version.

## 🌟 Feature

- 4\~96% faster than other GitHub Actions with the same purpose, especially when need to perform scan with multiple sessions.
- Ability to filter specify paths, rules, sessions, and/or signatures.
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

## 🧩 Input

> [!NOTE]
> All of the inputs are optional; Use this action without any input will default to scan with the ClamAV official assets.

### `clamav_enable`

`<boolean = true>` Whether to use ClamAV.

When this input is `false`, will ignore inputs:

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

`<string>` Artifact name of the ClamAV custom assets, which the artifact must uploaded in the same workflow run and before this action. When this is not defined, will ignore input [`clamav_customassets_use`](#clamav_customassets_use).

### `clamav_customassets_use`

`<RegExp[] = .+>` ClamAV custom assets to use, by regular expression of relative paths in the input [`clamav_customassets_artifact`](#clamav_customassets_artifact), separate each regular expression per line; By default, all of the ClamAV custom assets are in use.

### `yara_enable`

`<boolean = false>` Whether to use YARA.

When this input is `false`, will ignore inputs:

- [`yara_unofficialassets_use`](#yara_unofficialassets_use)
- [`yara_customassets_artifact`](#yara_customassets_artifact)
- [`yara_customassets_use`](#yara_customassets_use)

### `yara_unofficialassets_use`

`<RegExp[]>` YARA unofficial assets to use, by regular expression of names in the [YARA unofficial assets list](https://github.com/hugoalh/scan-virus-ghaction-assets/blob/main/yara/index.tsv), separate each regular expression per line; By default, all of the YARA unofficial assets are not in use.

### `yara_customassets_artifact`

`<string>` Artifact name of the YARA custom assets, which the artifact must uploaded in the same workflow run and before this action. When this is not defined, will ignore input [`yara_customassets_use`](#yara_customassets_use).

### `yara_customassets_use`

`<RegExp[] = .+>` YARA custom assets to use, by regular expression of relative paths in the input [`yara_customassets_artifact`](#yara_customassets_artifact), separate each regular expression per line; By default, all of the YARA custom assets are in use.

### `git_integrate`

`<boolean = false>` Whether to integrate with Git to perform scan by every commits; Require working directory is a Git repository.

When this input is `false`, will ignore inputs:

- [`git_ignores`](#git_ignores)
- [`git_lfs`](#git_lfs)
- [`git_limit`](#git_limit)
- [`git_reverse`](#git_reverse)

### `git_ignores`

`<function<boolean>>` Ignores Git commits, by JavaScript function and must return type of `boolean` (`true` to ignore). Ignored Git commits will not be scanned.

> **Available contexts:**
>
> - **`authorDate`:** `<Date>` Git commit author date.
> - **`authorEmail`:** `<string>` Git commit author e-mail.
> - **`authorName`:** `<string>` Git commit author name.
> - **`body`:** `<string>` Git commit body.
> - **`commitHash`:** `<string>` Git commit commit hash.
> - **`committerDate`:** `<Date>` Git commit committer date.
> - **`committerEmail`:** `<string>` Git commit committer e-mail.
> - **`committerName`:** `<string>` Git commit committer name.
> - **`encoding`:** `<string>` Git commit encoding.
> - **`notes`:** `<string>` Git commit notes.
> - **`parentHashes`:** `<string[]>` Git commit parent hashes.
> - **`reflogIdentityEmail`:** `<string>` Git commit reflog identity e-mail.
> - **`reflogIdentityName`:** `<string>` Git commit reflog identity name.
> - **`reflogSelector`:** `<string>` Git commit reflog selector.
> - **`reflogSubject`:** `<string>` Git commit reflog subject.
> - **`subject`:** `<string>` Git commit subject.
> - **`treeHash`:** `<string>` Git commit tree hash.

For example, to ignore Git commits made by Dependabot, and ignore Git commits made by OctoCat before 2022-01-01:

```yml
git_ignores: |-
  return (
    /^dependabot/iu.test(authorName) ||
    (authorDate.valueOf() < new Date("2022-01-01T00:00:00Z").valueOf() && /^octocat$/iu.test(authorName))
  );
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

### `ignores`

`<function<boolean>>` Ignores elements before the scan, by JavaScript function and must return type of `boolean` (`true` to ignore). Ignored elements will not be scanned.

To ignore only by the Git commits, use input [`git_ignores`](#git_ignores) is more efficiency. To ignore only by the tools, use inputs `*_enable` is more efficiency.

> **Available contexts:**
>
> - **`gitCommit.authorDate`:** `<Date | undefined>` Git commit author date. Only exists when the session is on a Git commit.
> - **`gitCommit.authorEmail`:** `<string | undefined>` Git commit author e-mail. Only exists when the session is on a Git commit.
> - **`gitCommit.authorName`:** `<string | undefined>` Git commit author name. Only exists when the session is on a Git commit.
> - **`gitCommit.body`:** `<string | undefined>` Git commit body. Only exists when the session is on a Git commit.
> - **`gitCommit.commitHash`:** `<string | undefined>` Git commit commit hash. Only exists when the session is on a Git commit.
> - **`gitCommit.committerDate`:** `<Date | undefined>` Git commit committer date. Only exists when the session is on a Git commit.
> - **`gitCommit.committerEmail`:** `<string | undefined>` Git commit committer e-mail. Only exists when the session is on a Git commit.
> - **`gitCommit.committerName`:** `<string | undefined>` Git commit committer name. Only exists when the session is on a Git commit.
> - **`gitCommit.encoding`:** `<string | undefined>` Git commit encoding. Only exists when the session is on a Git commit.
> - **`gitCommit.notes`:** `<string | undefined>` Git commit notes. Only exists when the session is on a Git commit.
> - **`gitCommit.parentHashes`:** `<string[] | undefined>` Git commit parent hashes. Only exists when the session is on a Git commit.
> - **`gitCommit.reflogIdentityEmail`:** `<string | undefined>` Git commit reflog identity e-mail. Only exists when the session is on a Git commit.
> - **`gitCommit.reflogIdentityName`:** `<string | undefined>` Git commit reflog identity name. Only exists when the session is on a Git commit.
> - **`gitCommit.reflogSelector`:** `<string | undefined>` Git commit reflog selector. Only exists when the session is on a Git commit.
> - **`gitCommit.reflogSubject`:** `<string | undefined>` Git commit reflog subject. Only exists when the session is on a Git commit.
> - **`gitCommit.subject`:** `<string | undefined>` Git commit subject. Only exists when the session is on a Git commit.
> - **`gitCommit.treeHash`:** `<string | undefined>` Git commit tree hash. Only exists when the session is on a Git commit.
> - **`path`:** `<string>` Relative path based on the current working directory without `./` (e.g.: `relative/path/to/file.extension`).
> - **`session`:** `<string>` `"Current"` or Git commit hash (equivalent with `gitCommit.commitHash`).
> - **`tool`:** `<string>` Tool ID (e.g.: `"clamav"`).

For example, to ignore path `node_modules`:

```yml
ignores: |-
  return /^node_modules\//u.test(path);
```

> [!CAUTION]
> JavaScript function is extremely powerful, which also able to execute malicious actions, user should always take extra review for this input value.

### `report_filter`

`<function<Severity = "High">>` Filter the report after the scan, by JavaScript function and must return type of `Severity`. By default, all of the symbols are high severity.

To ignore only by the paths and/or sessions, use input [`ignores`](#ignores) is more efficiency. To ignore only by the Git commits, use input [`git_ignores`](#git_ignores) is more efficiency. To ignore only by the tools, use inputs `*_enable` is more efficiency.

> **Available contexts:**
>
> - **`gitCommit.authorDate`:** `<Date | undefined>` Git commit author date. Only exists when the session is on a Git commit.
> - **`gitCommit.authorEmail`:** `<string | undefined>` Git commit author e-mail. Only exists when the session is on a Git commit.
> - **`gitCommit.authorName`:** `<string | undefined>` Git commit author name. Only exists when the session is on a Git commit.
> - **`gitCommit.body`:** `<string | undefined>` Git commit body. Only exists when the session is on a Git commit.
> - **`gitCommit.commitHash`:** `<string | undefined>` Git commit commit hash. Only exists when the session is on a Git commit.
> - **`gitCommit.committerDate`:** `<Date | undefined>` Git commit committer date. Only exists when the session is on a Git commit.
> - **`gitCommit.committerEmail`:** `<string | undefined>` Git commit committer e-mail. Only exists when the session is on a Git commit.
> - **`gitCommit.committerName`:** `<string | undefined>` Git commit committer name. Only exists when the session is on a Git commit.
> - **`gitCommit.encoding`:** `<string | undefined>` Git commit encoding. Only exists when the session is on a Git commit.
> - **`gitCommit.notes`:** `<string | undefined>` Git commit notes. Only exists when the session is on a Git commit.
> - **`gitCommit.parentHashes`:** `<string[] | undefined>` Git commit parent hashes. Only exists when the session is on a Git commit.
> - **`gitCommit.reflogIdentityEmail`:** `<string | undefined>` Git commit reflog identity e-mail. Only exists when the session is on a Git commit.
> - **`gitCommit.reflogIdentityName`:** `<string | undefined>` Git commit reflog identity name. Only exists when the session is on a Git commit.
> - **`gitCommit.reflogSelector`:** `<string | undefined>` Git commit reflog selector. Only exists when the session is on a Git commit.
> - **`gitCommit.reflogSubject`:** `<string | undefined>` Git commit reflog subject. Only exists when the session is on a Git commit.
> - **`gitCommit.subject`:** `<string | undefined>` Git commit subject. Only exists when the session is on a Git commit.
> - **`gitCommit.treeHash`:** `<string | undefined>` Git commit tree hash. Only exists when the session is on a Git commit.
> - **`path`:** `<string>` Relative path based on the current working directory without `./` (e.g.: `relative/path/to/file.extension`).
> - **`session`:** `<string>` `"Current"` or Git commit hash (equivalent with `gitCommit.commitHash`).
> - **`symbol`:** `<string>` Rule or signature (e.g.: `"Heuristics.Broken.Media.GIF.TruncatedScreenDescriptor"`).
> - **`tool`:** `<string>` Tool ID (e.g.: `"clamav"`).

> **Severity:**
>
>

For example, to adjust severity of symbol `Heuristics.Broken.Media.GIF.TruncatedScreenDescriptor`:

```yml
report_filter: |-
  if (symbol === "Heuristics.Broken.Media.GIF.TruncatedScreenDescriptor") {
    return "Low";
  }
```

> [!CAUTION]
> - It is not recommended to ignore any official symbol due to these rarely have false positives in most cases.
> - JavaScript function is extremely powerful, which also able to execute malicious actions, user should always take extra review for this input value.

### `report_sarif_enable`

`<boolean = false>` Whether to (allow to) generate the [SARIF report][sarif-github]. When this is `false`, will ignore input [`report_sarif_upload`](#report_sarif_upload).

> [!IMPORTANT]
> Due to the limitations, generate the [SARIF report][sarif-github] is only available when current working directory is a Git repository of the current repository, and input [`git_integrate`](#git_integrate) is `false`.

### `report_sarif_upload`

`<boolean = false>` Whether to (allow to) upload the [SARIF report][sarif-github] to the current repository.

### `token`

**🔒** `<string = ${{github.token}}>` GitHub token, require for upload the [SARIF report][sarif-github] to the current repository.

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
          uses: "actions/checkout@v4.1.1"
          with:
            fetch-depth: 0
        - name: "Scan Repository"
          uses: "hugoalh/scan-virus-ghaction@v0.30.0"
          with:
            git_ignores: |-
              return (
                /^dependabot/iu.test(authorName) ||
                (authorDate.valueOf() < new Date("2022-01-01T00:00:00Z").valueOf() && /^octocat$/iu.test(authorName))
              );
            git_limit: 100
            ignores_pre: |-
              return /^node_modules\//u.test(path);
  ```

## 📚 Guide

- GitHub
  - [SARIF support for code scanning][sarif-github]
- GitHub Actions
  - [Enabling debug logging](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/enabling-debug-logging)

[sarif-github]: https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning
