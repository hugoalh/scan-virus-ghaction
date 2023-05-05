# Scan Virus (GitHub Action)

![License](https://img.shields.io/static/v1?label=License&message=MIT&style=flat-square "License")
[![GitHub Repository](https://img.shields.io/badge/Repository-181717?logo=github&logoColor=ffffff&style=flat-square "GitHub Repository")](https://github.com/hugoalh/scan-virus-ghaction)
[![GitHub Stars](https://img.shields.io/github/stars/hugoalh/scan-virus-ghaction?label=Stars&logo=github&logoColor=ffffff&style=flat-square "GitHub Stars")](https://github.com/hugoalh/scan-virus-ghaction/stargazers)
[![GitHub Contributors](https://img.shields.io/github/contributors/hugoalh/scan-virus-ghaction?label=Contributors&logo=github&logoColor=ffffff&style=flat-square "GitHub Contributors")](https://github.com/hugoalh/scan-virus-ghaction/graphs/contributors)
[![GitHub Issues](https://img.shields.io/github/issues-raw/hugoalh/scan-virus-ghaction?label=Issues&logo=github&logoColor=ffffff&style=flat-square "GitHub Issues")](https://github.com/hugoalh/scan-virus-ghaction/issues)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr-raw/hugoalh/scan-virus-ghaction?label=Pull%20Requests&logo=github&logoColor=ffffff&style=flat-square "GitHub Pull Requests")](https://github.com/hugoalh/scan-virus-ghaction/pulls)
[![GitHub Discussions](https://img.shields.io/github/discussions/hugoalh/scan-virus-ghaction?label=Discussions&logo=github&logoColor=ffffff&style=flat-square "GitHub Discussions")](https://github.com/hugoalh/scan-virus-ghaction/discussions)
[![CodeFactor Grade](https://img.shields.io/codefactor/grade/github/hugoalh/scan-virus-ghaction?label=Grade&logo=codefactor&logoColor=ffffff&style=flat-square "CodeFactor Grade")](https://www.codefactor.io/repository/github/hugoalh/scan-virus-ghaction)

| **Releases** | **Latest** (![GitHub Latest Release Date](https://img.shields.io/github/release-date/hugoalh/scan-virus-ghaction?label=&style=flat-square "GitHub Latest Release Date")) | **Pre** (![GitHub Latest Pre-Release Date](https://img.shields.io/github/release-date-pre/hugoalh/scan-virus-ghaction?label=&style=flat-square "GitHub Latest Pre-Release Date")) |
|:-:|:-:|:-:|
| [![GitHub](https://img.shields.io/badge/GitHub-181717?logo=github&logoColor=ffffff&style=flat-square "GitHub")](https://github.com/hugoalh/scan-virus-ghaction/releases) ![GitHub Total Downloads](https://img.shields.io/github/downloads/hugoalh/scan-virus-ghaction/total?label=&style=flat-square "GitHub Total Downloads") | ![GitHub Latest Release Version](https://img.shields.io/github/release/hugoalh/scan-virus-ghaction?sort=semver&label=&style=flat-square "GitHub Latest Release Version") | ![GitHub Latest Pre-Release Version](https://img.shields.io/github/release/hugoalh/scan-virus-ghaction?include_prereleases&sort=semver&label=&style=flat-square "GitHub Latest Pre-Release Version") |

## 📝 Description

A GitHub Action to scan virus (including malicious file and malware) in the GitHub Action workspace.

### 🌟 Feature

- 4\~96% faster than other GitHub Actions with the same purpose, especially when need to perform scan with multiple sessions (e.g.: Git commits).
- Ability to ignore specify paths (i.e.: directories and/or files), rules, sessions (e.g.: Git commits), and/or signatures.
- Ability to scan other things, not limited to only Git repository.

### 🛡 Tools

- **[ClamAV](https://www.clamav.net):** Made by [Cisco](https://www.cisco.com), is an open source anti virus engine for detecting trojans, viruses, malwares, and other malicious threats.
  - [Unofficial Assets List][clamav-unofficial-assets-list]
- **[YARA](http://virustotal.github.io/yara):** Made by [VirusTotal](https://www.virustotal.com), is a tool aimed at but not limited to help malware researchers to identify and classify malware samples.
  - [Unofficial Assets List][yara-unofficial-assets-list]

### ⚠ Disclaimer

This does not provide any guarantee that carefully hidden objects will be scanned. Strong endpoint security, access, and code review policies and practices are the most effective way to ensure that malicious files and/or codes are not introduced. False positives maybe also will be happened.

## 📚 Documentation

> **⚠ Important:** This documentation is v0.10.0 based; To view other version's documentation, please visit the [versions list](https://github.com/hugoalh/scan-virus-ghaction/tags) and select the correct version.

### Getting Started

- GitHub Actions Runner >= v2.303.0
  - Docker

```yml
jobs:
  job_id:
    runs-on: "ubuntu-________"
    steps:
      - uses: "hugoalh/scan-virus-ghaction@<Version>"
```

### 📥 Input

> **ℹ Notice:** All of the inputs are optional; Use this action without any inputs will default to scan current workspace with the ClamAV official assets.

#### `input_listdelimiter`

`<RegEx = ",|;|\r?\n">` Delimiter when the input is type of list (i.e.: array), by regular expression.

#### `input_tablemarkup`

`<String = "yaml">` Markup language when the input is type of table.

- **`"csv"` (Comma Separated Values (Standard)):**
  ```csv
  bar,foo
  5,10
  10,20
  ```
- **`"csvm"` (Comma Separated Values (Non Standard Multiple Line)):**
  ```
  bar=5,foo=10
  bar=10,foo=20
  ```
- **`"csvs"` (Comma Separated Values (Non Standard Single Line)):**
  ```
  bar=5,foo=10;bar=10,foo=20
  ```
- **`"json"` (JavaScript Object Notation):**
  ```json
  [{"bar":5,"foo":10},{"bar":10,"foo":20}]
  ```
  ```json
  [
    {
      "bar": 5,
      "foo": 10
    },
    {
      "bar": 10,
      "foo": 20
    }
  ]
  ```
- **`"tsv"` (Tab Separated Values):**
  ```tsv
  bar	foo
  5	10
  10	20
  ```
- **`"yaml"`/`"yml"` (YAML) *\[Default\]*:**
  ```yml
  - bar: 5
    foo: 10
  - bar: 10
    foo: 20
  ```

#### `targets`

`<Uri[]>` Targets.

- **Local *\[Default\]*:** Workspace, for prepared files to the workspace (e.g.: checkout repository via action [`actions/checkout`](https://github.com/actions/checkout)) in the same job before this action.
- **Remote:** Fetch files from the remote to the workspace by this action, by HTTP/HTTPS URI, separate each target by [list delimiter (input `input_listdelimiter`)](#input_listdelimiter); Require a clean workspace.

When this input is defined (i.e.: remote targets), will ignore inputs:

- [`git_integrate`](#git_integrate)
- [`git_ignores`](#git_ignores)
- [`git_limit`](#git_limit)
- [`git_reverse`](#git_reverse)

#### `git_integrate`

`<Boolean = False>` Whether to integrate with Git to perform scan by the commits; Require workspace is a Git repository.

When this input is `False`, will ignore inputs:

- [`git_ignores`](#git_ignores)
- [`git_limit`](#git_limit)
- [`git_reverse`](#git_reverse)

#### `git_ignores`

[`<Table>`](#input_tablemarkup) Ignores for the Git commits, by table; Available properties:

- **`AuthorDate`:**
  - `<RegEx>` A regular expression to match the timestamp in ISO 8601 format
  - `<String>` A string with specify pattern to compare the timestamp:
    - `-ge %Y-%m-%dT%H:%M:%SZ` Author date that after or equal to this time.
    - `-gt %Y-%m-%dT%H:%M:%SZ` Author date that after this time.
    - `-le %Y-%m-%dT%H:%M:%SZ` Author date that before or equal to this time.
    - `-lt %Y-%m-%dT%H:%M:%SZ` Author date that before this time.
- **`AuthorEmail`:** `<RegEx>`
- **`AuthorName`:** `<RegEx>`
- **`Body`:** `<RegEx>`
- **`CommitHash`:** `<RegEx>`
- **`CommitterDate`:**
  - `<RegEx>` A regular expression to match the timestamp in ISO 8601 format
  - `<String>` A string with specify pattern to compare the timestamp:
    - `-ge %Y-%m-%dT%H:%M:%SZ` Committer date that after or equal to this time.
    - `-gt %Y-%m-%dT%H:%M:%SZ` Committer date that after this time.
    - `-le %Y-%m-%dT%H:%M:%SZ` Committer date that before or equal to this time.
    - `-lt %Y-%m-%dT%H:%M:%SZ` Committer date that before this time.
- **`CommitterEmail`:** `<RegEx>`
- **`CommitterName`:** `<RegEx>`
- **`Encoding`:** `<RegEx>`
- **`Notes`:** `<RegEx>`
- **`ParentHashes`:** `<RegEx>`
  - For multiple parent hashes in a commit, match any parent hash will cause ignore this commit.
- **`ReflogIdentityEmail`:** `<RegEx>`
- **`ReflogIdentityName`:** `<RegEx>`
- **`ReflogSelector`:** `<RegEx>`
- **`ReflogSubject`:** `<RegEx>`
- **`Subject`:** `<RegEx>`
- **`TreeHash`:** `<RegEx>`

Example:

```yml
ignores_gitcommits_meta: |-
  - AuthorName: "^dependabot$"
  - AuthorDate: "-lt 2022-01-01T00:00:00Z"
    AuthorName: "^octocat$"
```

#### `git_limit`

`<UInt>` Limit on how many Git commits will scan, counting is affected by inputs:

- [`git_ignores`](#git_ignores)
- [`git_reverse`](#git_reverse)

When this is not defined or defined with `0`, means no limit.

Example:

```yml
ignores_gitcommits_count: 100
```

> **⚠ Important:** For actions which run on the GitHub host, it is highly recommended to define this due to the time limit of the step execution time (currently is `6 hours`).

#### `git_reverse`

`<Boolean = False>` Whether to reverse the scan order of the Git commits.

- **`False`:** From the newest commit to the oldest commit.
- **`True`:** From the oldest commit to the newest commit.

#### `clamav_enable`

`<Boolean = True>` Whether to use ClamAV.

When this input is `False`, will ignore inputs:

- [`clamav_unofficialassets`](#clamav_unofficialassets)
- [`clamav_update`](#clamav_update)

#### `clamav_unofficialassets`

`<RegEx[]>` ClamAV unofficial assets to use, by regular expression and the [ClamAV unofficial assets list][clamav-unofficial-assets-list], separate each name by [list delimiter (input `input_listdelimiter`)](#input_listdelimiter); By default, all of the unofficial assets are not in use.

#### `clamav_update`

`<Boolean = True>` Whether to update the ClamAV official assets via FreshClam before scan anything.

> **⚠ Important:** It is recommended to keep this enable to have the latest ClamAV official assets.

#### `yara_enable`

`<Boolean = False>` Whether to use YARA. When this input is `False`, will ignore input [`yara_unofficialassets`](#yara_unofficialassets).

#### `yara_unofficialassets`

`<RegEx[]>` YARA unofficial assets to use, by regular expression and the [YARA unofficial assets list][yara-unofficial-assets-list], separate each name by [list delimiter (input `input_listdelimiter`)](#input_listdelimiter); By default, all of the unofficial assets are not in use.

#### `ignores`

[`<Table>`](#input_tablemarkup) Ignores for the paths, rules (YARA), sessions, and/or signatures (ClamAV), by table. Available properties (i.e.: keys):

- **`Tool`:** `<RegEx>` Tool name, only useful with properties `Path` and/or `Session`.
- **`Path`:** `<RegEx>` Relative path based on GitHub Action workspace without `./` (e.g.: `path/to/file.extension`).
- **`Rule`:** `<RegEx>` `{Index}/{RuleName}`.
- **`Session`:** `<RegEx>` Git commit hash.
- **`Signature`:** `<RegEx>` `{Platform}.{Category}.{Name}-{SignatureID}-{Revision}`.

Example:

```yml
ignores_elements: |-
  - Path: "^node_modules"
```

> **⚠ Important:**
>
> - It is not recommended to use this on the ClamAV official signatures due to these rarely have false positives in most cases.
> - ClamAV unofficial signatures maybe not follow the recommended signatures name pattern.

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
        uses: "actions/checkout@v3.5.2"
        with:
          fetch-depth: 0
      - name: "Scan Repository"
        uses: "hugoalh/scan-virus-ghaction@v0.10.0"
```

### Guide

#### GitHub Actions

- [Enabling debug logging](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/enabling-debug-logging)

[clamav-unofficial-assets-list]: ./assets/clamav-unofficial/index.tsv
[yara-unofficial-assets-list]: ./assets/yara-unofficial/index.tsv
