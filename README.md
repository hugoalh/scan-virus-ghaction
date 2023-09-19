# Scan Virus (GitHub Action)

[⚖️ MIT](./LICENSE.md)
[![CodeFactor Grade](https://img.shields.io/codefactor/grade/github/hugoalh/scan-virus-ghaction?label=Grade&logo=codefactor&logoColor=ffffff&style=flat-square "CodeFactor Grade")](https://www.codefactor.io/repository/github/hugoalh/scan-virus-ghaction)

|  | **Heat** | **Release - Latest** | **Release - Pre** |
|:-:|:-:|:-:|:-:|
| [![GitHub](https://img.shields.io/badge/GitHub-181717?logo=github&logoColor=ffffff&style=flat-square "GitHub")](https://github.com/hugoalh/scan-virus-ghaction) | [![GitHub Stars](https://img.shields.io/github/stars/hugoalh/scan-virus-ghaction?label=&logoColor=ffffff&style=flat-square "GitHub Stars")](https://github.com/hugoalh/scan-virus-ghaction/stargazers) \| ![GitHub Total Downloads](https://img.shields.io/github/downloads/hugoalh/scan-virus-ghaction/total?label=&style=flat-square "GitHub Total Downloads") | ![GitHub Latest Release Version](https://img.shields.io/github/release/hugoalh/scan-virus-ghaction?sort=semver&label=&style=flat-square "GitHub Latest Release Version") (![GitHub Latest Release Date](https://img.shields.io/github/release-date/hugoalh/scan-virus-ghaction?label=&style=flat-square "GitHub Latest Release Date")) | ![GitHub Latest Pre-Release Version](https://img.shields.io/github/release/hugoalh/scan-virus-ghaction?include_prereleases&sort=semver&label=&style=flat-square "GitHub Latest Pre-Release Version") (![GitHub Latest Pre-Release Date](https://img.shields.io/github/release-date-pre/hugoalh/scan-virus-ghaction?label=&style=flat-square "GitHub Latest Pre-Release Date")) |

A GitHub Action to scan virus (including malicious file and malware) in the GitHub Action workspace.

> **⚠️ Important:** This documentation is v0.17.0 based; To view other version's documentation, please visit the [versions list](https://github.com/hugoalh/scan-virus-ghaction/tags) and select the correct version.

## 🌟 Feature

- 4\~96% faster than other GitHub Actions with the same purpose, especially when need to perform scan with multiple sessions (e.g.: Git commits).
- Ability to ignore specify paths (i.e.: directories and/or files), rules, sessions (e.g.: Git commits), and/or signatures.
- Ability to scan other things, not limited to only Git repository.

## 🛡️ Tools

- **[ClamAV](https://www.clamav.net):** Made by [Cisco](https://www.cisco.com), is an open source anti virus engine for detecting trojans, viruses, malwares, and other malicious threats.
- **[YARA](http://virustotal.github.io/yara):** Made by [VirusTotal](https://www.virustotal.com), is a tool aimed at but not limited to help malware researchers to identify and classify malware samples.

### Unofficial Assets

Some of the communities have publicly published unofficial ClamAV and/or YARA assets for free. In order to adoptable, compatible, and usable with this action, these unofficial assets are stored in [hugoalh/scan-virus-ghaction-assets](https://github.com/hugoalh/scan-virus-ghaction-assets).

Inputs that use these unofficial assets are:

- [`unofficialassets_version`](#unofficialassets_version)
- [`unofficialassets_clamav`](#unofficialassets_clamav) / [`clamav_unofficialassets`](#clamav_unofficialassets)
- [`unofficialassets_yara`](#unofficialassets_yara) / [`yara_unofficialassets`](#yara_unofficialassets)

## ⚠️ Disclaimer

This does not provide any guarantee that carefully hidden objects will be scanned. Strong endpoint security, access, and code review policies and practices are the most effective way to ensure that malicious files and/or codes are not introduced. False positives maybe also will be happened.

## 🔰 Begin

### GitHub Actions

- **Target Version:** >= v2.308.0, &:
  - Docker
- **Require Permission:** *N/A*

```yml
jobs:
  job_id:
    runs-on: "ubuntu-________"
    steps:
      - uses: "hugoalh/scan-virus-ghaction@<Tag>"
```

> **ℹ️ Notice:** This action also provide editions of each tool:
>
> - **ClamAV:** `"hugoalh/scan-virus-ghaction/clamav@<Tag>"`
> - **YARA:** `"hugoalh/scan-virus-ghaction/yara@<Tag>"`

## 🧩 Input

> **ℹ️ Notice:** All of the inputs are optional; Use this action without any input will default to:
>
> - **`@<Tag>`:** Scan current workspace with the ClamAV official assets
> - **`/clamav@<Tag>`:** Scan current workspace with the ClamAV official assets
> - **`/yara@<Tag>`:** Scan current workspace with the YARA unofficial assets

### `input_listdelimiter`

`<RegEx = ",|;|\r?\n">` Delimiter when the input is accept list of values, by regular expression.

### `input_tablemarkup`

`<String = "yaml">` Markup language when the input is type of table.

- **`"Csv"` (Comma Separated Values (Standard)):**
  - ```csv
    bar,foo
    5,10
    10,20
    ```
- **`"CsvM"` (Comma Separated Values (Non Standard Multiple Line)):**
  - ```
    bar=5,foo=10
    bar=10,foo=20
    ```
- **`"CsvS"` (Comma Separated Values (Non Standard Single Line)):**
  - ```
    bar=5,foo=10;bar=10,foo=20
    ```
- **`"Json"` (JavaScript Object Notation):**
  - ```json
    [{"bar":5,"foo":10},{"bar":10,"foo":20}]
    ```
  - ```json
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
- **`"Tsv"` (Tab Separated Values):**
  - ```tsv
    bar	foo
    5	10
    10	20
    ```
- **`"Yaml"`/`"Yml"` (YAML) *\[Default\]*:**
  - ```yml
    - bar: 5
      foo: 10
    - bar: 10
      foo: 20
    ```

### `targets`

`<Uri[]>` Targets.

- **Local *\[Default\]*:** Workspace, for prepared files to the workspace (e.g.: checkout repository via action [`actions/checkout`](https://github.com/actions/checkout)) in the same job before this action.
- **Remote:** Fetch files from the remote to the workspace by this action, by HTTP/HTTPS URI, separate each target by [list delimiter (input `input_listdelimiter`)](#input_listdelimiter); Require a clean workspace.

When this is defined (i.e.: remote targets), will ignore inputs:

- [`git_integrate`](#git_integrate)
- [`git_ignores`](#git_ignores)
- [`git_lfs`](#git_lfs)
- [`git_limit`](#git_limit)
- [`git_reverse`](#git_reverse)

> **⚠️ Important:** Workspace will automatically clean for remote targets.

### `git_integrate`

`<Boolean = False>` Whether to integrate with Git to perform scan by the commits; Require workspace is a Git repository.

When this is `False`, will ignore inputs:

- [`git_ignores`](#git_ignores)
- [`git_lfs`](#git_lfs)
- [`git_limit`](#git_limit)
- [`git_reverse`](#git_reverse)

### `git_ignores`

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

> **✍️ Example:**
>
> ```yml
> git_ignores: |-
>   - AuthorName: "^dependabot$"
>   - AuthorDate: "-lt 2022-01-01T00:00:00Z"
>     AuthorName: "^octocat$"
> ```

### `git_lfs`

`<Boolean = False>` Whether to process Git LFS files.

### `git_limit`

`<UInt64>` Limit on how many Git commits will scan, counting is affected by inputs [`git_ignores`](#git_ignores) and [`git_reverse`](#git_reverse); When this is not defined or defined with `0`, means no limit.

> **✍️ Example:**
>
> ```yml
> git_limit: 100
> ```

> **⚠️ Important:** For actions which run on the GitHub host, it is highly recommended to define this due to the limit of the job execution time (currently is `6 hours`).

### `git_reverse`

`<Boolean = False>` Whether to reverse the scan order of the Git commits.

- **`False`:** From the newest commit to the oldest commit.
- **`True`:** From the oldest commit to the newest commit.

### `clamav_enable`

`<Boolean = True>` Whether to use ClamAV.

When this is `False`, will ignore inputs:

- [`clamav_unofficialassets`](#clamav_unofficialassets)
- [`clamav_update`](#clamav_update)

### `clamav_unofficialassets`

*Alias of input [`unofficialassets_clamav`](#unofficialassets_clamav).*

### `clamav_update`

`<Boolean = True>` Whether to update the ClamAV official assets via FreshClam before scan anything.

> **⚠️ Important:** It is recommended to keep this enable to have the latest ClamAV official assets.

### `yara_enable`

`<Boolean = False>` Whether to use YARA. When this is `False`, will ignore input [`yara_unofficialassets`](#yara_unofficialassets).

### `yara_unofficialassets`

*Alias of input [`unofficialassets_yara`](#unofficialassets_yara).*

### `unofficialassets_version`

`<String>` Git tree-ish of the [unofficial assets store](#unofficial-assets). By default, bundled version of the unofficial assets are use.

### `unofficialassets_clamav`

`<RegEx[]>` ClamAV unofficial assets to use, by regular expression and the ClamAV unofficial assets list, separate each name by [list delimiter (input `input_listdelimiter`)](#input_listdelimiter); By default, all of the unofficial assets are not in use.

### `unofficialassets_yara`

`<RegEx[]>` YARA unofficial assets to use, by regular expression and the YARA unofficial assets list, separate each name by [list delimiter (input `input_listdelimiter`)](#input_listdelimiter).

> **⚠️ Important:** All of the unofficial assets are in use if not specified.

### `ignores`

[`<Table>`](#input_tablemarkup) Ignores for the paths, rules (YARA), sessions, and/or signatures (ClamAV), by table. Available properties:

- **`Path`:** `<RegEx>` Relative path based on GitHub Action workspace without `./` (e.g.: `path/to/file.extension`).
- **`Session`:** `<RegEx>` Git commit hash.
- **`Symbol`:** `<RegEx>`
  - Rule (YARA)
  - Signature (ClamAV) (`{Platform}.{Category}.{Name}-{SignatureID}-{Revision}`)
- **`Tool`:** `<RegEx>` Tool name, only useful with properties `Path` and/or `Session`.

> **✍️ Example:**
>
> ```yml
> ignores: |-
>   - Path: "^node_modules\\/"
> ```

> **⚠️ Important:**
>
> - It is not recommended to use this on the ClamAV official signatures due to these rarely have false positives in most cases.
> - ClamAV unofficial signatures maybe not follow the recommended signatures name pattern.
> - YARA rules are have their owned rules name pattern.

### `log_elements`

`<String = "All">` Whether to list elements in the log.

- **`"None"`:** Disable.
- **`"OnlyCurrent"`:** Enable, only for session "Current".
- **`"All"`:** Enable.

> **⚠️ Important:** Begin from v0.16.0, elements are list in the log only when enabled debug mode.

### `summary_found`

`<String = "None">` Whether to list elements which found virus in the step summary.

- **`"None"`:** Disable, and record in the log.
- **`"Clone"`:** Enable, and still record in the log.
- **`"Redirect"`:** Enable, and will not record in the log.

> **⚠️ Important:** If there has many elements which found virus, step summary maybe get truncated and unable to display all of them.

### `summary_statistics`

`<String = "None">` Whether to list statistics in the step summary.

- **`"None"`:** Disable, and record in the log.
- **`"Clone"`:** Enable, and still record in the log.
- **`"Redirect"`:** Enable, and will not record in the log.

> **⚠️ Important:** If there has many elements which found virus, step summary maybe get truncated and unable to display statistics.

## 🧩 Output

### `finish`

`<Boolean>` Whether this action correctly finished without non catch issues.

### `found`

`<Boolean>` Whether there has element which found virus.

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
          uses: "hugoalh/scan-virus-ghaction@v0.17.0"
          with:
            git_ignores: |-
              - AuthorName: "^dependabot$"
              - AuthorDate: "-lt 2022-01-01T00:00:00Z"
                AuthorName: "^octocat$"
            git_limit: 100
            ignores: |-
              - Path: "^node_modules\\/"
  ```

## 📚 Guide

- GitHub Actions
  - [Enabling debug logging](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/enabling-debug-logging)
