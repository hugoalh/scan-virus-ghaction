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

A GitHub Action to scan virus (including malicious files and malware) in the GitHub Action workspace.

### 🛡 Anti Virus Software

- [ClamAV](https://www.clamav.net)
  > ClamAV, by [Cisco](https://www.cisco.com), is an open source anti virus engine for detecting trojans, viruses, malware, and other malicious threats.
- **(>= v0.6.0)** [YARA](http://virustotal.github.io/yara) ([Rules List][yara-rules-list])
  > YARA, by [VirusTotal](https://www.virustotal.com), is a tool aimed at but not limited to help malware researchers to identify and classify malware samples.

### ⚠ Disclaimer

This action does not provide any guarantee that carefully hidden objects will be scanned. Strong endpoint security, access, and code review policies and practices are the most effective way to ensure that malicious files and/or codes are not introduced. False positives maybe also will be happened.

### 🌟 Feature

- 4\~96% faster than other GitHub Actions with the same purpose, especially when need to scan every Git commits.
- Ability to scan other things, not limited to only Git repository.

## 📚 Documentation

> **⚠ Important:** This documentation is v0.6.0 based; To view other tag's/version's documentation, please visit the [tags/versions list](https://github.com/hugoalh/scan-virus-ghaction/tags) and select the correct tag/version.

### 🎯 Entrypoint / Target

```yml
jobs:
  job_id:
    runs-on: "ubuntu-________"
    steps:
      - uses: "hugoalh/scan-virus-ghaction@<tag/version>"
```

Require Software:

- Docker

### 📥 Input

#### `targets`

**\[Optional\]** `<string[] = "./">` Targets.

- **Local (`"./"`):** Workspace, for previously checkouted repository via [`actions/checkout`](https://github.com/actions/checkout), or previously prepared files to workspace.
- **Network:** Fetch files from network to workspace, by HTTP/HTTPS URL, separate each target with semicolon (`;`) or per line.
  > **⚠ Important:**
  >
  > - Each files is recommanded to limit sizes for maximum 4 GB to prevent unexpected error/hang.
  > - Require a clean workspace.

When this input is network, will ignore inputs:

- `clamav_filesfilter_list`
- `clamav_filesfilter_mode`
- `yara_filesfilter_list`
- `yara_filesfilter_mode`

#### `deep`

**\[Optional\]** `<boolean = false>` Scan deeper for Git repository, will scan each commits. When this input is `false`, will ignore input `git_reversesession`.

#### `git_reversesession`

**\[Optional\]** `<boolean = false>` Reverse Git session.

- **`false`:** From oldest to newest.
- **`true`:** From newest to oldest.

#### `clamav_enable`

**\[Optional\]** `<boolean = true>` Use ClamAV.

#### `clamav_filesfilter_list`

**\[Optional\]** `<string[] = "">` ClamAV files filter list, by [PowerShell regular expressions](#PowerShell-Regular-Expressions), separate each target with semicolon (`;`) or per line.

#### `clamav_filesfilter_mode`

**\[Optional\]** `<string = "exclude">` ClamAV files filter mode.

- **`"exclude"`:** Exclude files in input `clamav_filesfilter_list`.
- **`"include"`:** Only include files in input `clamav_filesfilter_list`.

#### `clamav_multiscan`

**\[Optional\]** `<boolean = true>` Use ClamAV "multiscan" mode, ClamAV daemon will attempt to scan in parallel using available threads, especially useful on multiprocessor and multi-core systems.

> **⚠ Important:** It is recommended to keep this as enable to have a shorter scanning duration.

#### `yara_enable`

**\[Optional\]** `<boolean = false>` Use YARA.

> **⚠ Important:** This is disable by default due to YARA can throw many false positives in most cases.

#### `yara_filesfilter_list`

**\[Optional\]** `<string[] = "">` YARA files filter list, by [PowerShell regular expressions](#PowerShell-Regular-Expressions), separate each target with semicolon (`;`) or per line.

#### `yara_filesfilter_mode`

**\[Optional\]** `<string = "exclude">` YARA files filter mode.

- **`"exclude"`:** Exclude files in input `yara_filesfilter_list`.
- **`"include"`:** Only include files in input `yara_filesfilter_list`.

#### `yara_rulesfilter_list`

**\[Optional\]** `<string[] = "">` YARA rules filter list, by [PowerShell regular expressions](#PowerShell-Regular-Expressions) and [rules list][yara-rules-list]'s name, separate each rule with semicolon (`;`) or per line.

To filter specifically, separate main rule and sub-rule with forward slash (`/`) (i.e.: backward slash and forward slash (`\/`) for regular expressions), and sub-rule and file with right angle bracket (`>`). For full pattern:

```
^<Main>\/<Sub>><File>$
```

For example with main rule is `foo`, sub-rule is `bar`, file is `goob`:

| **Pattern** | **Example** |
|:-:|:-:|
| Main + Sub | `^foo\/bar` |
| Main + File | `^foo\/.+>goob$` |
| Sub + File | `\/bar>goob$` |
| Main + Sub + File | `^foo\/bar>goob$` |

#### `yara_rulesfilter_mode`

**\[Optional\]** `<string = "exclude">` YARA rules filter mode.

- **`"exclude"`:** Exclude rules in input `yara_rulesfilter_list`.
- **`"include"`:** Only include rules in input `yara_rulesfilter_list`.

#### `yara_warning`

**\[Optional\]** `<boolean = false>` Enable YARA warning.

> **⚠ Important:** It is recommended to keep this as disable due to YARA can throw many warnings about deprecated features, while user-end does not need these informations in most cases.

#### PowerShell Regular Expressions

[Regular expressions in PowerShell](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions) is slightly different to others, forward slash (`/`) does not need at the start and end of the regular expressions.

Also, when defining the regular expressions, it is important to note that the target is considered valid if the regular expression matches anywhere within the target. For example, the regular expression `p` will match any target with a "p" in it, such as "apple" not just a target that is simply "p". Therefore, it is usually less confusing, as a matter of course, to surround the regular expression in `^...$` form (e.g.: `^p$`), unless there is a good reason not to do so.

| **JavaScript** | **PowerShell** |
|:-:|:-:|
| `/p/` | `p` |
| `/^foo/` | `^foo` |
| `/\//` | `\/` |

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
        uses: "actions/checkout@v3.0.0"
        with:
          fetch-depth: 0
      - name: "Scan Repository"
        uses: "hugoalh/scan-virus-ghaction@v0.6.0"
```

### Guide

#### GitHub Actions

- [Enabling debug logging](https://docs.github.com/en/actions/managing-workflow-runs/enabling-debug-logging)

[yara-rules-list]: ./yara-rules/index.tsv
