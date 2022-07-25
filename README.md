# Scan Virus (GitHub Action)

[`ScanVirus.GitHubAction`](https://github.com/hugoalh/scan-virus-ghaction)
[![GitHub Contributors](https://img.shields.io/github/contributors/hugoalh/scan-virus-ghaction?label=Contributors&logo=github&logoColor=ffffff&style=flat-square)](https://github.com/hugoalh/scan-virus-ghaction/graphs/contributors)
[![GitHub Issues](https://img.shields.io/github/issues-raw/hugoalh/scan-virus-ghaction?label=Issues&logo=github&logoColor=ffffff&style=flat-square)](https://github.com/hugoalh/scan-virus-ghaction/issues)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr-raw/hugoalh/scan-virus-ghaction?label=Pull%20Requests&logo=github&logoColor=ffffff&style=flat-square)](https://github.com/hugoalh/scan-virus-ghaction/pulls)
[![GitHub Discussions](https://img.shields.io/github/discussions/hugoalh/scan-virus-ghaction?label=Discussions&logo=github&logoColor=ffffff&style=flat-square)](https://github.com/hugoalh/scan-virus-ghaction/discussions)
[![GitHub Stars](https://img.shields.io/github/stars/hugoalh/scan-virus-ghaction?label=Stars&logo=github&logoColor=ffffff&style=flat-square)](https://github.com/hugoalh/scan-virus-ghaction/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/hugoalh/scan-virus-ghaction?label=Forks&logo=github&logoColor=ffffff&style=flat-square)](https://github.com/hugoalh/scan-virus-ghaction/network/members)
![GitHub Languages](https://img.shields.io/github/languages/count/hugoalh/scan-virus-ghaction?label=Languages&logo=github&logoColor=ffffff&style=flat-square)
[![CodeFactor Grade](https://img.shields.io/codefactor/grade/github/hugoalh/scan-virus-ghaction?label=Grade&logo=codefactor&logoColor=ffffff&style=flat-square)](https://www.codefactor.io/repository/github/hugoalh/scan-virus-ghaction)
[![License](https://img.shields.io/static/v1?label=License&message=MIT&style=flat-square)](./LICENSE.md)

| **Release** | **Latest** (![GitHub Latest Release Date](https://img.shields.io/github/release-date/hugoalh/scan-virus-ghaction?label=%20&style=flat-square)) | **Pre** (![GitHub Latest Pre-Release Date](https://img.shields.io/github/release-date-pre/hugoalh/scan-virus-ghaction?label=%20&style=flat-square)) |
|:-:|:-:|:-:|
| [**GitHub**](https://github.com/hugoalh/scan-virus-ghaction/releases) ![GitHub Total Downloads](https://img.shields.io/github/downloads/hugoalh/scan-virus-ghaction/total?label=%20&style=flat-square) | ![GitHub Latest Release Version](https://img.shields.io/github/release/hugoalh/scan-virus-ghaction?sort=semver&label=%20&style=flat-square) | ![GitHub Latest Pre-Release Version](https://img.shields.io/github/release/hugoalh/scan-virus-ghaction?include_prereleases&sort=semver&label=%20&style=flat-square) |

## 📝 Description

A GitHub Action to scan virus (including malicious file and malware) in the GitHub Action workspace.

### 🛡 Anti Virus Software

- **[ClamAV](https://www.clamav.net):** Made by [Cisco](https://www.cisco.com), is an open source anti virus engine for detecting trojans, viruses, malwares, and other malicious threats.
  - [Unofficial Signatures List][clamav-unofficial-signatures-list]
- **[YARA](http://virustotal.github.io/yara):** Made by [VirusTotal](https://www.virustotal.com), is a tool aimed at but not limited to help malware researchers to identify and classify malware samples.
  - [Rules List][yara-rules-list]

### ⚠ Disclaimer

This action does not provide any guarantee that carefully hidden objects will be scanned. Strong endpoint security, access, and code review policies and practices are the most effective way to ensure that malicious files and/or codes are not introduced. False positives maybe also will be happened.

### 🌟 Feature

- 4\~96% faster than other GitHub Actions with the same purpose, especially when need to scan every Git commits.
- Ability to scan other things, not limited to only Git repository.
- Files filter to scan specify directories and/or files or not.

## 📚 Documentation

> **⚠ Important:** This documentation is v0.10.0 based; To view other tag's/version's documentation, please visit the [tags/versions list](https://github.com/hugoalh/scan-virus-ghaction/tags) and select the correct tag/version.

### 🎯 Entrypoint / Target

```yml
jobs:
  job_id:
    runs-on: "________"
    steps:
      - uses: "hugoalh/scan-virus-ghaction________@<Tag/Version>"
```

|  | **`jobs.job_id.runs-on`** | **`jobs.job_id.steps[*].uses`** | **Require Software** |
|:-:|:-:|:-:|:-:|
| **Default** | `ubuntu-________` | *None* | Docker |

### 📥 Input

> **ℹ Notice:** All inputs are optional.

#### `input_listdelimiter`

`<RegEx = ",|;|\r?\n">` Delimiter when input is type of list (i.e.: array), by regular expression.

#### `input_tableparser`

`<String = "yaml">` Paser to use when input is type of table:

- `csv`
  ```csv
  bar,foo
  5,10
  10,20
  ```
- `csv-kv-singleline`
  ```
  bar=5,foo=10;bar=10,foo=20
  ```
- `csv-kv-multipleline`
  ```
  bar=5,foo=10
  bar=10,foo=20
  ```
- `tsv`
  ```tsv
  bar	foo
  5	10
  10	20
  ```
- `yaml`/`yml`
  ```yml
  - bar: 5
    foo: 10
  - bar: 10
    foo: 20
  ```

#### `targets`

`<Uri[]>` Targets.

| **Type** | **Description** |
|:-:|:--|
| Local (Default) | Workspace, for prepared files to the workspace in the same job before this action (e.g.: checkout repository via [`actions/checkout`](https://github.com/actions/checkout)). |
| Network | Fetch files from network to the workspace, by HTTP/HTTPS URI, separate each target by [list delimiter (input `input_listdelimiter`)](#input_listdelimiter); Require a clean workspace. |

When this input is defined (i.e.: network type), will ignore inputs:

- [`git_integrate`](#git_integrate)
- [`git_ignores`](#git_ignores)
- [`git_reverse`](#git_reverse)

#### `git_integrate`

`<Boolean = False>` Integrate with Git to scan every commits; Require workspace is a Git repository.

When this input is `False`, will ignore inputs:

- [`git_ignores`](#git_ignores)
- [`git_reverse`](#git_reverse)

#### `git_ignores`

`<Table<{String:RegEx}>>` Git ignores (for commits), by table with type of key is string (`<String>`) and type of value is regular expression (`<RegEx>`).

Git commits' information are provided by [Git CLI `git log`](https://git-scm.com/docs/git-log), but only these properties (i.e.: keys) are available (properties which have not listed in here are not supported):

- `AuthorDate` (ISO8601 UTC (end with `Z`))
- `AuthorEmail`
- `AuthorName`
- `Body`
- `CommitHash`
- `CommitterDate` (ISO8601 UTC (end with `Z`))
- `CommitterEmail`
- `CommitterName`
- `Encoding`
- `GPGSignatureKey`
- `GPGSignatureKeyFingerprint`
- `GPGSignaturePrimaryKeyFingerprint`
- `GPGSignatureSigner`
- `GPGSignatureStatus`
- `GPGSignatureTrustLevel`
- `Notes`
- `ReflogIdentityEmail`
- `ReflogIdentityName`
- `ReflogSelector`
- `ReflogSubject`
- `ShortenedReflogSelector`
- `Subject`
- `TreeHash`

Example:

```yml
- AuthorName: ^octokit$
  CommitterName: ^octokit$
```

#### `git_reverse`

`<Boolean = False>` Reverse scan order of the Git commits.

- **`False`:** From oldest commit to newest commit.
- **`True`:** From newest commit to oldest commit.

#### `clamav_enable`

`<Boolean = True>` Use ClamAV.

When this input is `False`, will ignore inputs:

- [`clamav_daemon`](#clamav_daemon)
- [`clamav_ignores`](#clamav_ignores)
- [`clamav_multiscan`](#clamav_multiscan)
- [`clamav_reloadpersession`](#clamav_reloadpersession)
- [`clamav_subcursive`](#clamav_subcursive)
- [`clamav_unofficialsignatures`](#clamav_unofficialsignatures)

#### `clamav_daemon`

`<Boolean = True>` Use ClamAV daemon.

When this input is `False`, will ignore inputs:

- [`clamav_multiscan`](#clamav_multiscan)
- [`clamav_reloadpersession`](#clamav_reloadpersession)

> **⚠ Important:**
>
> - It is recommended to keep this as enable to have a shorter scanning duration.
> - When this input is `False`, will have limitations to protect the system against DoS attacks:
>   - Extract and scan at most 25 MB from each archive.
>   - Extract and scan at most 100 MB from each scanned file.
>   - Extract at most 10000 files from each scanned file (when this is an archive, a document or another kind of container).
>   - Maximum 15 depth directories are scanned.
>   - Maximum 16 archive recursion levels.

#### `clamav_ignores`

`<Table<{String:RegEx}>>` ClamAV ignores (for files, sessions, and/or signatures), by table with type of key is string (`<String>`) and type of value is regular expression (`<RegEx>`).

Available properties (i.e.: keys):

- `Path` (Relative path based at GitHub Action workspace without `./` (e.g.: Path`/`To`/`File`.`Extension))
- `Session` (`Current`, Git commit hash, or HTTP/HTTPS URI)
- `Signature` (Platform`.`Category`.`Name`-`SignatureID`-`Revision)

Example:

```yml
- Path: ^node_modules
```

> **⚠ Important:**
>
> - If this acts weird, try to disable input [`clamav_subcursive`](#clamav_subcursive) first before report the issues!
> - It is not recommended to use this on ClamAV official signatures due to these rarely have false positives in most cases.
> - ClamAV unofficial signatures maybe not follow the recommended signatures name pattern.

#### `clamav_multiscan`

`<Boolean = True>` Use ClamAV multiscan mode; ClamAV daemon will attempt to scan in parallel using available threads, especially useful on multiprocessor and multi-core systems.

> **⚠ Important:** It is recommended to keep this as enable to have a shorter scanning duration.

#### `clamav_reloadpersession`

`<Boolean = False>` Reload ClamAV per session.

> **⚠ Important:** It is recommended to keep this as disable to have a shorter scanning duration.

#### `clamav_subcursive`

`<Boolean = True>` Scan directories subcursively.

> **⚠ Important:** If input [`clamav_ignores`](#clamav_ignores) acts weird, try to disable this first before report the issues!

#### `clamav_unofficialsignatures`

`<RegEx[]>` Use ClamAV unofficial signatures, by regular expression and [ClamAV unofficial signatures list][clamav-unofficial-signatures-list], separate each signature with [list delimiter (input `input_listdelimiter`)](#input_listdelimiter); By default, all of the unofficial signatures are not in use.

> **⚠ Important:** It is not recommended to use this due to ClamAV unofficial signatures have more false positives than official signatures in most cases.

#### `yara_enable`

`<Boolean = False>` Use YARA.

When this input is `False`, will ignore inputs:

- [`yara_ignores`](#yara_ignores)
- [`yara_rules`](#yara_rules)
- [`yara_toolwarning`](#yara_toolwarning)

> **⚠ Important:** It is not recommended to use this due to YARA rules can have many false positives in most cases.

#### `yara_ignores`

`<Table<{String:RegEx}>>` YARA ignores (for files, rules, and/or sessions), by table with type of key is string (`<String>`) and type of value is regular expression (`<RegEx>`).

Available properties (i.e.: keys):

- `Path` (Relative path based at GitHub Action workspace without `./` (e.g.: Path`/`To`/`File`.`Extension))
- `Rule` (Index`/`RuleName)
- `Session` (`Current`, Git commit hash, or HTTP/HTTPS URI)

Example:

```yml
- Path: ^node_modules
```

#### `yara_rules`

`<RegEx[]>` Use YARA rules, by regular expression and [YARA rules list][yara-rules-list], separate each rule by [list delimiter (input `input_listdelimiter`)](#input_listdelimiter); By default, all of the rules are not in use.

#### `yara_toolwarning`

`<Boolean = False>` Enable YARA tool warning.

> **⚠ Important:** It is recommended to keep this as disable due to YARA rules can have many warnings about deprecated features, while client does not need these informations in most cases.

### 📤 Output

*N/A*

### Example

```yml
jobs:
  job_id:
    name: "Scan Virus"
    runs-on: "ubuntu-latest"
    steps:
      - name: "Checkout Repository"
        uses: "actions/checkout@v3.0.2"
        with:
          fetch-depth: 0
      - name: "Scan Repository"
        uses: "hugoalh/scan-virus-ghaction@v0.10.0"
```

### Guide

#### GitHub Actions

- [Enabling debug logging](https://docs.github.com/en/actions/managing-workflow-runs/enabling-debug-logging)

[clamav-unofficial-signatures-list]: https://github.com/hugoalh/scan-virus-ghaction-assets/raw/main/clamav-unofficial-signatures/index.tsv
[yara-rules-list]: https://github.com/hugoalh/scan-virus-ghaction-assets/raw/main/yara-rules/index.tsv
