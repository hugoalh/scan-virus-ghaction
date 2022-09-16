# Scan Virus (GitHub Action)

[`ScanVirus.GitHubAction`](https://github.com/hugoalh/scan-virus-ghaction)
[![GitHub Contributors](https://img.shields.io/github/contributors/hugoalh/scan-virus-ghaction?label=Contributors&logo=github&logoColor=ffffff&style=flat-square)](https://github.com/hugoalh/scan-virus-ghaction/graphs/contributors)
[![GitHub Issues](https://img.shields.io/github/issues-raw/hugoalh/scan-virus-ghaction?label=Issues&logo=github&logoColor=ffffff&style=flat-square)](https://github.com/hugoalh/scan-virus-ghaction/issues)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr-raw/hugoalh/scan-virus-ghaction?label=Pull%20Requests&logo=github&logoColor=ffffff&style=flat-square)](https://github.com/hugoalh/scan-virus-ghaction/pulls)
[![GitHub Discussions](https://img.shields.io/github/discussions/hugoalh/scan-virus-ghaction?label=Discussions&logo=github&logoColor=ffffff&style=flat-square)](https://github.com/hugoalh/scan-virus-ghaction/discussions)
[![GitHub Stars](https://img.shields.io/github/stars/hugoalh/scan-virus-ghaction?label=Stars&logo=github&logoColor=ffffff&style=flat-square)](https://github.com/hugoalh/scan-virus-ghaction/stargazers)
[![CodeFactor Grade](https://img.shields.io/codefactor/grade/github/hugoalh/scan-virus-ghaction?label=Grade&logo=codefactor&logoColor=ffffff&style=flat-square)](https://www.codefactor.io/repository/github/hugoalh/scan-virus-ghaction)
[![License](https://img.shields.io/static/v1?label=License&message=MIT&color=brightgreen&style=flat-square)](./LICENSE.md)

| **Release** | **Latest** (![GitHub Latest Release Date](https://img.shields.io/github/release-date/hugoalh/scan-virus-ghaction?label=%20&style=flat-square)) | **Pre** (![GitHub Latest Pre-Release Date](https://img.shields.io/github/release-date-pre/hugoalh/scan-virus-ghaction?label=%20&style=flat-square)) |
|:-:|:-:|:-:|
| [**GitHub**](https://github.com/hugoalh/scan-virus-ghaction/releases) ![GitHub Total Downloads](https://img.shields.io/github/downloads/hugoalh/scan-virus-ghaction/total?label=%20&style=flat-square) | ![GitHub Latest Release Version](https://img.shields.io/github/release/hugoalh/scan-virus-ghaction?sort=semver&label=%20&style=flat-square) | ![GitHub Latest Pre-Release Version](https://img.shields.io/github/release/hugoalh/scan-virus-ghaction?include_prereleases&sort=semver&label=%20&style=flat-square) |

## 📝 Description

A GitHub Action to scan virus (including malicious files and malware) in the GitHub Action workspace.

### ⚠ Disclaimer

This action does not provide any guarantee that carefully hidden objects will be scanned. Strong endpoint security, access, and code review policies and practices are the most effective way to ensure that malicious files and/or codes are not introduced. False positives maybe also will be happened.

### 🛡 Tools

- [ClamAV](https://www.clamav.net)
  > ClamAV, by [Cisco](https://www.cisco.com), is an open source anti virus engine for detecting trojans, viruses, malware, and other malicious threats.
- **(>= v0.6.0)** [YARA](http://virustotal.github.io/yara) ([Rules List][yara-rules-list])
  > YARA, by [VirusTotal](https://www.virustotal.com), is a tool aimed at but not limited to help malware researchers to identify and classify malware samples.

### 🌟 Feature

- 4\~96% faster than other GitHub Actions with the same purpose, especially when need to scan every Git commits.
- Ability to scan other things, not limited to only Git repository.
- Files filter to scan specify directories and/or files or not.

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

- **Local (`"./"`):** Workspace, for checkouted repository via [`actions/checkout`](https://github.com/actions/checkout) or prepared files to workspace before this action.
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

#### `git_deep`

**\[Optional\]** `<boolean = false>` Scan deeper for Git repository, will scan each commits. When this input is `false`, will ignore input `git_reversesession`.

#### `git_reversesession`

**\[Optional\]** `<boolean = false>` Reverse Git session.

- **`false`:** From oldest to newest.
- **`true`:** From newest to oldest.

#### `clamav_enable`

**\[Optional\]** `<boolean = true>` Use ClamAV. When this input is `false`, will ignore inputs:

- `clamav_daemon`
- `clamav_filesfilter_list`
- `clamav_filesfilter_mode`
- `clamav_multiscan`
- `clamav_reloadpersession`
- `clamav_signaturesignore_custom`
- `clamav_signaturesignore_presets`
- `clamav_subcursive`

#### `clamav_daemon`

**(>= v0.6.1) \[Optional\]** `<boolean = true>` Use ClamAV daemon. When this input is `false`, will ignore inputs:

- `clamav_multiscan`
- `clamav_reloadpersession`

> **⚠ Important:**
>
> - It is recommended to keep this as enable to have a shorter scanning duration.
> - When this input is `false`, will have limitations to protect the system against DoS attacks:
>   - Extract and scan at most 25 MB from each archive.
>   - Extract and scan at most 100 MB from each scanned file.
>   - Extract at most 10000 files from each scanned file (when this is an archive, a document or another kind of container).
>   - Maximum 15 depth directories are scanned.
>   - Maximum 16 archive recursion levels.

#### `clamav_filesfilter_list`

**\[Optional\]** `<string[] = "">` ClamAV files filter list, by [PowerShell regular expressions](#PowerShell-Regular-Expressions), separate each target with semicolon (`;`) or per line.

#### `clamav_filesfilter_mode`

**\[Optional\]** `<string = "exclude">` ClamAV files filter mode.

- **`"exclude"`:** Exclude files in input `clamav_filesfilter_list`.
- **`"include"`:** Only include files in input `clamav_filesfilter_list`.

#### `clamav_multiscan`

**\[Optional\]** `<boolean = true>` Use ClamAV "multiscan" mode, ClamAV daemon will attempt to scan in parallel using available threads, especially useful on multiprocessor and multi-core systems.

> **⚠ Important:** It is recommended to keep this as enable to have a shorter scanning duration.

#### `clamav_reloadpersession`

**(>= v0.6.1) \[Optional\]** `<boolean = false>` Reload ClamAV per session.

> **⚠ Important:** It is recommended to keep this as disable to have a shorter scanning duration.

#### `clamav_signaturesignore_custom`

**(>= v0.6.1) \[Optional\]** `<string[] = "">` Ignore individual ClamAV signatures, separate each signature with semicolon (`;`) or per line.

> **⚠ Important:**
>
> - It is not recommended to use this due to ClamAV rarely throw false positives in most cases.
> - Signatures must be exactly the same in order to ignore.
> - This is unable to filter signatures with specify directories and/or files.
> - This is unable to only include specify signatures.

#### `clamav_signaturesignore_presets`

**(>= v0.6.1) \[Optional\]** `<string[] = "">` Ignore ClamAV signatures by [presets list][clamav-signatures-ignore-presets-list], separate each preset with semicolon (`;`) or per line.

> **⚠ Important:**
>
> - It is not recommended to use this due to ClamAV rarely throw false positives in most cases.
> - This is unable to filter presets with specify directories and/or files.
> - This is unable to only include specify presets.

#### `clamav_subcursive`

**(>= v0.6.1) \[Optional\]** `<boolean = true>` Scan directories subcursively.

> **⚠ Important:** If there has issues at the input `clamav_filesfilter_list`, try to disable this first before report the issues!

#### `clamav_unofficialsignatures`

**(>= v0.6.1) \[Optional\]** `<string[] = "">` ClamAV unofficial signatures, by [PowerShell regular expressions](#PowerShell-Regular-Expressions) and [signatures list][clamav-unofficial-signatures-list], separate each rule with semicolon (`;`) or per line.

> **⚠ Important:** It is not recommended to use this due to ClamAV official signature is less false positives in most cases.

#### `yara_enable`

**\[Optional\]** `<boolean = false>` Use YARA. When this input is `false`, will ignore inputs:

- `yara_filesfilter_list`
- `yara_filesfilter_mode`
- `yara_rulesfilter_list`
- `yara_rulesfilter_mode`
- `yara_toolwarning`

> **⚠ Important:** This is disable by default due to YARA can throw many false positives in most cases.

#### `yara_filesfilter_list`

**\[Optional\]** `<string[] = "">` YARA files filter list, by [PowerShell regular expressions](#PowerShell-Regular-Expressions), separate each target with semicolon (`;`) or per line.

#### `yara_filesfilter_mode`

**\[Optional\]** `<string = "exclude">` YARA files filter mode.

- **`"exclude"`:** Exclude files in input `yara_filesfilter_list`.
- **`"include"`:** Only include files in input `yara_filesfilter_list`.

#### `yara_rulesfilter_list`

**\[Optional\]** `<string[] = "">` YARA rules filter list, by [PowerShell regular expressions](#PowerShell-Regular-Expressions) and [rules list][yara-rules-list], separate each rule with semicolon (`;`) or per line.

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

#### `yara_toolwarning`

**\[Optional\]** `<boolean = false>` Enable YARA tool warning.

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

[clamav-signatures-ignore-presets-list]: ./clamav-signatures-ignore-presets/index.tsv
[clamav-unofficial-signatures-list]: ./clamav-unofficial-signatures/index.tsv
[yara-rules-list]: ./yara-rules/index.tsv
