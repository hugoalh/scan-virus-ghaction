# Scan Virus (GitHub Action)

[`ScanVirus.GitHubAction`](https://github.com/hugoalh/scan-virus-ghaction)

![License](https://img.shields.io/static/v1?label=License&message=MIT&style=flat-square "License")
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
  - [Unofficial Signatures List][clamav-unofficial-signatures-list]
- **[YARA](http://virustotal.github.io/yara):** Made by [VirusTotal](https://www.virustotal.com), is a tool aimed at but not limited to help malware researchers to identify and classify malware samples.
  - [Rules List][yara-rules-list]

### ⚠ Disclaimer

This does not provide any guarantee that carefully hidden objects will be scanned. Strong endpoint security, access, and code review policies and practices are the most effective way to ensure that malicious files and/or codes are not introduced. False positives maybe also will be happened.

## 📚 Documentation

> **⚠ Important:** This documentation is v0.10.0 based; To view other version's documentation, please visit the [versions list](https://github.com/hugoalh/scan-virus-ghaction/tags) and select the correct version.

### Getting Started

#### Install (For Self Host)

- GitHub Actions Runner >= v2.297.0
  - Docker

#### Use

```yml
jobs:
  job_id:
    runs-on: "ubuntu-________"
    steps:
      - uses: "hugoalh/scan-virus-ghaction@<Version>"
```

### 📥 Input

> **ℹ Notice:** All inputs are optional; Use this action without any inputs will default to scan current workspace with ClamAV official signatures.

#### `input_list_delimiter`

`<RegEx = ",|;|\r?\n">` Delimiter when the input is type of list (i.e.: array), by regular expression.

#### `input_table_parser`

`<String = "yaml">` Parser when the input is type of table.

<table>
<tr>
<td align="center"><b>Parser Name</b></td>
<td><b>Parser ID</b></td>
<td><b>Example</b></td>
</tr>
<tr>
<td align="center">CSV (Comma Separated Values)</td>
<td><code>csv</code></td>
<td>

```csv
bar,foo
5,10
10,20
```

</td>
</tr>
<tr>
<td align="center">CSV (Comma Separated Values) Single Line</code></td>
<td>
<ul>
<li><code>csv-s</code></li>
<li><code>csv-singleline</code></li>
</ul>
</td>
<td>

```
bar=5,foo=10;bar=10,foo=20
```

</td>
</tr>
<tr>
<td align="center">CSV (Comma Separated Values) Multiple Line</td>
<td>
<ul>
<li><code>csv-m</code></li>
<li><code>csv-multipleline</code></li>
</ul>
</td>
<td>

```
bar=5,foo=10
bar=10,foo=20
```

</td>
</tr>
<tr>
<td align="center">TSV (Tab Separated Values)</td>
<td><code>tsv</code></td>
<td>

```tsv
bar	foo
5	10
10	20
```

</td>
</tr>
<tr>
<td align="center">YAML/YML (YAML Ain't Markup Language)</td>
<td>
<ul>
<li><code>yaml</code></li>
<li><code>yml</code></li>
</ul>
</td>
<td>

```yml
- bar: 5
  foo: 10
- bar: 10
  foo: 20
```

</td>
</tr>
</table>

#### `targets`

`<Uri[]>` Targets.

- **Local *\[Default\]*:** Workspace, for prepared files to the workspace (e.g.: checkout repository via action [`actions/checkout`](https://github.com/actions/checkout)) in the same job before this action.
- **Network:** Fetch files from the network to the workspace by this action, by HTTP/HTTPS URI, separate each target by [list delimiter (input `input_list_delimiter`)](#input_list_delimiter); Require a clean workspace.

When this input is defined (i.e.: network targets), will ignore inputs:

- [`git_integrate`](#git_integrate)
- [`git_ignores`](#git_ignores)
- [`git_include_allbranches`](#git_include_allbranches)
- [`git_include_reflogs`](#git_include_reflogs)
- [`git_reverse`](#git_reverse)
- [`git_saferquery`](#git_saferquery)

#### `git_integrate`

`<Boolean = False>` Whether to integrate with Git to perform scan by the commits; Require workspace is a Git repository.

When this input is `False`, will ignore inputs:

- [`git_ignores`](#git_ignores)
- [`git_include_allbranches`](#git_include_allbranches)
- [`git_include_reflogs`](#git_include_reflogs)
- [`git_reverse`](#git_reverse)
- [`git_saferquery`](#git_saferquery)

#### `git_ignores`

[`<Table>`](#input_table_parser) Ignores for the Git commits, by table; Available properties:

- **`AuthorDate`:**
  - `<RegEx>` A regular expression to match the timestamp ISO8601 UTC string (end with `Z`)
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
  - `<RegEx>` A regular expression to match the timestamp ISO8601 UTC string (end with `Z`)
  - `<String>` A string with specify pattern to compare the timestamp:
    - `-ge %Y-%m-%dT%H:%M:%SZ` Committer date that after or equal to this time.
    - `-gt %Y-%m-%dT%H:%M:%SZ` Committer date that after this time.
    - `-le %Y-%m-%dT%H:%M:%SZ` Committer date that before or equal to this time.
    - `-lt %Y-%m-%dT%H:%M:%SZ` Committer date that before this time.
- **`CommitterEmail`:** `<RegEx>`
- **`CommitterName`:** `<RegEx>`
- **`Encoding`:** `<RegEx>`
- **`GPGSignatureKey`:** `<RegEx>`
- **`GPGSignatureKeyFingerprint`:** `<RegEx>`
- **`GPGSignaturePrimaryKeyFingerprint`:** `<RegEx>`
- **`GPGSignatureSigner`:** `<RegEx>`
- **`GPGSignatureStatus`:** `<RegEx>`
- **`GPGSignatureTrustLevel`:** `<RegEx>`
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
- AuthorName: "^octocat$"
  CommitterDate: "-lt 2022-01-01T00:00:00Z"
  CommitterName: "^octocat$"
```

> **ℹ Notice:** For GitHub host users, it is highly recommended to ignore old commits due to the time limit of the step execution time (currently is `6 hours`).

#### `git_include_allbranches`

`<Boolean = False>` Whether to include the Git commits which not in the default branch.

#### `git_include_reflogs`

`<Boolean = False>` Whether to include the Git commits which marked as references (e.g.: dead end commits).

#### `git_reverse`

`<Boolean = False>` Whether to reverse the scan order of the Git commits.

- **`False`:** From the newest commit to the oldest commit.
- **`True`:** From the oldest commit to the newest commit.

#### `git_saferquery`

`<Boolean = True>` Whether to query the Git commits meta in a safer way.

- **`False`:** Fast, but it can cause issues when:
  - repository contains multiple commits with extremely long commit message,
  - repository contains extremely high amount of commits,
  - GitHub Actions runner is out of RAM.
- **`True`:** Slow, but it will not cause any issues.

#### `clamav_enable`

`<Boolean = True>` Whether to use ClamAV.

When this input is `False`, will ignore inputs:

- [`clamav_daemon`](#clamav_daemon)
- [`clamav_ignores`](#clamav_ignores)
- [`clamav_multiscan`](#clamav_multiscan)
- [`clamav_reloadpersession`](#clamav_reloadpersession)
- [`clamav_subcursive`](#clamav_subcursive)
- [`clamav_unofficialsignatures`](#clamav_unofficialsignatures)

#### `clamav_daemon`

`<Boolean = True>` Whether to use ClamAV daemon.

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

[`<Table>`](#input_table_parser) Ignores for the ClamAV's paths, sessions, and/or signatures, by table. Available properties (i.e.: keys):

- **`Path`:** `<RegEx>` Relative path based at GitHub Action workspace without `./` (e.g.: Path`/`To`/`File`.`Extension)
- **`Session`:** `<RegEx>` `Current`, Git commit hash, or HTTP/HTTPS URI
- **`Signature`:** `<RegEx>` Platform`.`Category`.`Name`-`SignatureID`-`Revision

Example:

```yml
- Path: ^node_modules
```

> **⚠ Important:**
>
> - If this acts weird, try to disable input [`clamav_subcursive`](#clamav_subcursive) first before report the issues!
> - It is not recommended to use this on the ClamAV official signatures due to these rarely have false positives in most cases.
> - ClamAV unofficial signatures maybe not follow the recommended signatures name pattern.

#### `clamav_multiscan`

`<Boolean = True>` Whether to use ClamAV multiscan mode; ClamAV daemon will attempt to scan in parallel using available threads, especially useful on multiprocessor and multi-core systems.

> **⚠ Important:** It is recommended to keep this as enable to have a shorter scanning duration.

#### `clamav_reloadpersession`

`<Boolean = False>` Whether to reload ClamAV per session.

> **⚠ Important:** It is recommended to keep this as disable to have a shorter scanning duration.

#### `clamav_subcursive`

`<Boolean = True>` Whether to scan directories subcursively.

> **⚠ Important:** If input [`clamav_ignores`](#clamav_ignores) acts weird, try to disable this first before report the issues!

#### `clamav_unofficialsignatures`

`<RegEx[]>` Use ClamAV unofficial signatures, by regular expression and [ClamAV unofficial signatures list][clamav-unofficial-signatures-list], separate each signature with [list delimiter (input `input_list_delimiter`)](#input_list_delimiter); By default, all of the unofficial signatures are not in use.

> **⚠ Important:** It is not recommended to use this due to ClamAV unofficial signatures have more false positives than official signatures in most cases.

#### `yara_enable`

`<Boolean = False>` Whether to use YARA.

When this input is `False`, will ignore inputs:

- [`yara_ignores`](#yara_ignores)
- [`yara_rules`](#yara_rules)
- [`yara_toolwarning`](#yara_toolwarning)

> **⚠ Important:** It is not recommended to use this due to YARA rules can have many false positives in most cases.

#### `yara_ignores`

[`<Table>`](#input_table_parser) Ignores for the YARA's paths, rules, and/or sessions, by table. Available properties (i.e.: keys):

- **`Path`:** `<RegEx>` Relative path based at GitHub Action workspace without `./` (e.g.: Path`/`To`/`File`.`Extension)
- **`Rule`:** `<RegEx>` Index`/`RuleName
- **`Session`:** `<RegEx>` `Current`, Git commit hash, or HTTP/HTTPS URI

Example:

```yml
- Path: ^node_modules
```

#### `yara_rules`

`<RegEx[]>` Use YARA rules, by regular expression and [YARA rules list][yara-rules-list], separate each rule by [list delimiter (input `input_list_delimiter`)](#input_list_delimiter); By default, all of the rules are not in use.

#### `update_assets`

`<Boolean = True>` Whether to update ClamAV unofficial signatures and YARA rules from the [assets repository][assets-repository] before scan anything.

> **⚠ Important:**
>
> - When inputs [`clamav_unofficialsignatures`](#clamav_unofficialsignatures) and [`yara_rules`](#yara_rules) are not defined, will skip this update in order to save some times.
> - It is recommended to keep this as enable to have the latest assets.

#### `update_clamav`

`<Boolean = True>` Whether to update ClamAV official signatures via FreshClam before scan anything.

> **⚠ Important:**
>
> - When input [`clamav_enable`](#clamav_enable) is `False`, will skip this update in order to save some times.
> - It is recommended to keep this as enable to have the latest ClamAV official signatures.

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
        uses: "actions/checkout@v3.1.0"
        with:
          fetch-depth: 0
      - name: "Scan Repository"
        uses: "hugoalh/scan-virus-ghaction@v0.10.0"
```

### Guide

#### GitHub Actions

- [Enabling debug logging](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/enabling-debug-logging)

[assets-repository]: https://github.com/hugoalh/scan-virus-ghaction-assets
[clamav-unofficial-signatures-list]: https://github.com/hugoalh/scan-virus-ghaction-assets/main/clamav-unofficial-signatures/index.tsv
[yara-rules-list]: https://github.com/hugoalh/scan-virus-ghaction-assets/main/yara-rules/index.tsv
