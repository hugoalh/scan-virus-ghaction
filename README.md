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
[![License](https://img.shields.io/static/v1?label=License&message=MIT&color=brightgreen&style=flat-square)](./LICENSE.md)

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

> **⚠ Important:** This documentation is v0.7.0 based; To view other tag's/version's documentation, please visit the [tags/versions list](https://github.com/hugoalh/scan-virus-ghaction/tags) and select the correct tag/version.

### 🎯 Entrypoint / Target

```yml
jobs:
  job_id:
    runs-on: "ubuntu-________"
    steps:
      - uses: "hugoalh/scan-virus-ghaction@<Tag/Version>"
```

Require Software:

- Docker

### 📥 Input

> **ℹ Notice:** All inputs are optional.

#### `input_listdelimiter`

`<RegEx = ";|\r?\n">` Delimiter when input is type of list (i.e.: array).

#### `targets`

`<Uri[]>` Targets.

| **Type** | **Description** |
|:-:|:--|
| Local (Default) | Workspace, for checkouted repository via [`actions/checkout`](https://github.com/actions/checkout) or prepared files to workspace before this action. |
| Network | Fetch files from network to workspace, by HTTP/HTTPS URI, separate each target with [input list delimiter (input `input_listdelimiter`)](#input_listdelimiter); Require a clean workspace. |

When this input is defined (i.e.: network type), will ignore inputs:

- [`clamav_filesfilter`](#clamav_filesfilter)
- [`git_integrate`](#git_integrate)
- [`git_reverse`](#git_reverse)
- [`yara_filesfilter`](#yara_filesfilter)

#### `git_integrate`

`<Boolean = False>` Integrate with Git to scan every commits; Require workspace is a Git repository.

When this input is `False`, will ignore input [`git_reverse`](#git_reverse).

#### `git_reverse`

`<Boolean = False>` Reverse scan order of Git commits.

- **`False`:** From oldest commit to newest commit.
- **`True`:** From newest commit to oldest commit.

#### `clamav_enable`

`<Boolean = True>` Use ClamAV.

When this input is `False`, will ignore inputs:

- [`clamav_daemon`](#clamav_daemon)
- [`clamav_filesfilter`](#clamav_filesfilter)
- [`clamav_multiscan`](#clamav_multiscan)
- [`clamav_reloadpersession`](#clamav_reloadpersession)
- [`clamav_resultsfilter`](#clamav_resultsfilter)
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

#### `clamav_filesfilter`

`<String[]>` ClamAV files filter, by [filter syntax](#Filter-Syntax), separate each target with [input list delimiter (input `input_listdelimiter`)](#input_listdelimiter).

> **⚠ Important:** If this acts weird, try to disable input [`clamav_subcursive`](#clamav_subcursive) first before report the issues!

#### `clamav_multiscan`

`<Boolean = True>` Use ClamAV multiscan mode; ClamAV daemon will attempt to scan in parallel using available threads, especially useful on multiprocessor and multi-core systems.

> **⚠ Important:** It is recommended to keep this as enable to have a shorter scanning duration.

#### `clamav_reloadpersession`

`<Boolean = False>` Reload ClamAV per session.

> **⚠ Important:** It is recommended to keep this as disable to have a shorter scanning duration.

#### `clamav_resultsfilter`

`<String[]>` ClamAV results filter, by [filter syntax](#Filter-Syntax), separate each condition with [input list delimiter (input `input_listdelimiter`)](#input_listdelimiter).

> **⚠ Important:** It is not recommended to use this on ClamAV official signatures due to these rarely have false positives in most cases.

#### `clamav_subcursive`

`<Boolean = True>` Scan directories subcursively.

> **⚠ Important:** If input [`clamav_filesfilter`](#clamav_filesfilter) acts weird, try to disable this first before report the issues!

#### `clamav_unofficialsignatures`

`<String[] = "-^.+$">` Use ClamAV unofficial signatures, by [filter syntax](#Filter-Syntax) and [ClamAV unofficial signatures list][clamav-unofficial-signatures-list], separate each signature with [input list delimiter (input `input_listdelimiter`)](#input_listdelimiter); By default, all of the unofficial signatures are not in use.

> **⚠ Important:** It is not recommended to use this due to ClamAV unofficial signatures have more false positives than official signatures in most cases.

#### `yara_enable`

`<Boolean = False>` Use YARA.

When this input is `False`, will ignore inputs:

- [`yara_filesfilter`](#yara_filesfilter)
- [`yara_resultsfilter`](#yara_resultsfilter)
- [`yara_rules`](#yara_rules)
- [`yara_toolwarning`](#yara_toolwarning)

> **⚠ Important:** It is not recommended to use this due to YARA rules can have many false positives in most cases.

#### `yara_filesfilter`

`<String[]>` YARA files filter, by [filter syntax](#Filter-Syntax), separate each target with [input list delimiter (input `input_listdelimiter`)](#input_listdelimiter).

#### `yara_resultsfilter`

`<String[]>` YARA results filter, by [filter syntax](#Filter-Syntax), separate each condition with [input list delimiter (input `input_listdelimiter`)](#input_listdelimiter).

#### `yara_rules`

`<String[]>` Use YARA rules, by [filter syntax](#Filter-Syntax) and [YARA rules list][yara-rules-list], separate each rule with [input list delimiter (input `input_listdelimiter`)](#input_listdelimiter).

#### `yara_toolwarning`

`<Boolean = False>` Enable YARA tool warning.

> **⚠ Important:** It is recommended to keep this as disable due to YARA rules can have many warnings about deprecated features, while client does not need these informations in most cases.

#### Filter Syntax

> **⚠ Important:** Filter syntax is modified for this action, and maybe different to others.

Filter syntax is based on Glob and [PowerShell regular expressions](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions) with additional modifications, behaviour similar to Glob pattern, include filter will have higher priority than exclude filter.

To create an exclude filter, use hyphen/minus (`-`) as prefix; To create an include filter, use add/plus (`+`) as prefix; Filters with incorrect prefix or missing prefix are invalid. For example, to create filters which exclude any items end with `o` but need to include `foo`:

```
-o$
+^foo$
```

Different sort orders will not cause differences, so this is also the same:

```
+^foo$
-o$
```

When defining the regular expressions, forward slash (`/`) does not need at the start and end of the regular expressions; Also it is important to note that the target is considered valid if the regular expression matches anywhere within the target. For example, the regular expression `p` will match any target with a "p" in it, such as "apple" not just a target that is simply "p". Therefore, it is usually less confusing, as a matter of course, to surround the regular expression in `^...$` form (e.g.: `^p$`), unless there is a good reason not to do so.

For inputs [`clamav_resultsfilter`](#clamav_resultsfilter) and [`yara_resultsfilter`](#yara_resultsfilter), these inputs use additional syntax to help for filter results by directories/files, rules/signatures, and sessions.

| **Full Pattern:** | **Rules/Signatures** | `>` | **Directories/Files** | `>` | **Sessions** |
|--:|:-:|:-:|:-:|:-:|:-:|
| **[`clamav_resultsfilter`](#clamav_resultsfilter)** | Platform`.`Category`.`Name`-`SignatureID`-`Revision\* |  | Path`/`To`/`File`.`Extension |  | `Current` ***or*** Git Commit Hash |
| **[`yara_resultsfilter`](#yara_resultsfilter)** | IndexName`/`RuleName |  | Path`/`To`/`File`.`Extension |  | `Current` ***or*** Git Commit Hash |

**\*:** ClamAV unofficial signatures maybe not follow this recommended signatures name pattern.

For example, to create filters which exclude ClamAV signature `JavaScript.Test.Something`, YARA index name is `github/octokit` and rule name is `foo-bar`, file is `hyper.mjs`, and session is `Current`:

```yml
# Rules/Signatures only
-^JavaScript\.Test\.Something>
-^github\/octokit\/foo-bar>

# Directories/Files only (recommended to use inputs `clamav_filesfilter` and `yara_filesfilter` for better efficiency)
# (Either)
-^.+?>hyper\.mjs>
->hyper\.mjs>.+$

# Sessions only
# (Either)
-^.+?>.+?>Current$
->Current$

# Rules/Signatures + Directories/Files
-^JavaScript\.Test\.Something>hyper\.mjs>
-^github\/octokit\/foo-bar>hyper\.mjs>

# Rules/Signatures + Sessions
-^JavaScript\.Test\.Something>.+?>Current$
-^github\/octokit\/foo-bar>.+?>Current$

# Rules/Signatures + Directories/Files + Sessions
-^JavaScript\.Test\.Something>hyper\.mjs>Current$
-^github\/octokit\/foo-bar>hyper\.mjs>Current$
```

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
        uses: "hugoalh/scan-virus-ghaction@v0.7.0"
```

### Guide

#### GitHub Actions

- [Enabling debug logging](https://docs.github.com/en/actions/managing-workflow-runs/enabling-debug-logging)

[clamav-signatures-ignore-presets-list]: https://github.com/hugoalh/scan-virus-ghaction-assets/raw/main/clamav-signatures-ignore-presets/index.tsv
[clamav-unofficial-signatures-list]: https://github.com/hugoalh/scan-virus-ghaction-assets/raw/main/clamav-unofficial-signatures/index.tsv
[yara-rules-list]: https://github.com/hugoalh/scan-virus-ghaction-assets/raw/main/yara-rules/index.tsv
