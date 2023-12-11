# Scan Virus (GitHub Action)

[⚖️ MIT](./LICENSE.md)
[![CodeFactor Grade](https://img.shields.io/codefactor/grade/github/hugoalh/scan-virus-ghaction?label=Grade&logo=codefactor&logoColor=ffffff&style=flat-square "CodeFactor Grade")](https://www.codefactor.io/repository/github/hugoalh/scan-virus-ghaction)

|  | **Release - Latest** | **Release - Pre** |
|:-:|:-:|:-:|
| [![GitHub](https://img.shields.io/badge/GitHub-181717?logo=github&logoColor=ffffff&style=flat-square "GitHub")](https://github.com/hugoalh/scan-virus-ghaction) | ![GitHub Latest Release Version](https://img.shields.io/github/release/hugoalh/scan-virus-ghaction?sort=semver&label=&style=flat-square "GitHub Latest Release Version") (![GitHub Latest Release Date](https://img.shields.io/github/release-date/hugoalh/scan-virus-ghaction?label=&style=flat-square "GitHub Latest Release Date")) | ![GitHub Latest Pre-Release Version](https://img.shields.io/github/release/hugoalh/scan-virus-ghaction?include_prereleases&sort=semver&label=&style=flat-square "GitHub Latest Pre-Release Version") (![GitHub Latest Pre-Release Date](https://img.shields.io/github/release-date-pre/hugoalh/scan-virus-ghaction?label=&style=flat-square "GitHub Latest Pre-Release Date")) |

A GitHub Action to scan virus (including malicious file and malware).

> **⚠️ Important:** This documentation is v0.20.0 based; To view other version's documentation, please visit the [versions list](https://github.com/hugoalh/scan-virus-ghaction/tags) and select the correct version.

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

### GitHub Actions - Docker

- **Target Version:** >= v2.311.0, &:
  - Docker
- **Require Permission:** *N/A*

```yml
jobs:
  job_id:
    runs-on: "ubuntu-________"
    steps:
      - uses: "hugoalh/scan-virus-ghaction@<Tag>" # Docker, All (Default)
      - uses: "hugoalh/scan-virus-ghaction/clamav@<Tag>" # Docker, Only ClamAV
      - uses: "hugoalh/scan-virus-ghaction/yara@<Tag>" # Docker, Only YARA
```

### GitHub Actions - Native

> **🧪 Experimental:** Still under development.

- **Target Version:** >= v2.311.0, &:
  - Git ^ v2.43.0
  - NodeJS ^ v20.9.0
  - **For Linux:**
    - apt-get (Advanced Packaging Tools)
  - **For MacOS:**
    - Homebrew ^ v4.1.0
  - **For Windows:**
    - Chocolatey ^ v2.2.0
- **Require Permission:** *N/A*

```yml
jobs:
  job_id:
    runs-on: "________" # Any
    steps:
      - uses: "hugoalh/scan-virus-ghaction/native@<Tag>" # Native, All
      - uses: "hugoalh/scan-virus-ghaction/native-clamav@<Tag>" # Native, Only ClamAV
      - uses: "hugoalh/scan-virus-ghaction/native-yara@<Tag>" # Native, Only YARA
```

## 🧩 Input

> **ℹ️ Notice:** All of the inputs are optional; Use this action without any input will default to:
>
> | **Variant** | **Behaviour** |
> |:-:|:--|
> | All | Scan with the ClamAV official assets. |
> | Only ClamAV | Scan with the ClamAV official assets. |
> | Only YARA | Scan with the YARA unofficial assets. |

### `operate_setup_pre`

> **🧪 Experimental:** Still under development.

|  | **Docker, All (Default)** | **Docker, Only ClamAV** | **Docker, Only YARA** | **Native, All** | **Native, Only ClamAV** | **Native, Only YARA** |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Availability** | ❌ | ❌ | ❌ | ✔️ | ✔️ | ✔️ |
| **Type** | *N/A* | *N/A* | *N/A* | `<boolean = false>` | `<boolean = false>` | `<boolean = false>` |

**(>= v0.21.0)** Whether to setup at the pre step instead of at the main step.

### `operate_cleanup_enable`

> **🧪 Experimental:** Still under development.

|  | **Docker, All (Default)** | **Docker, Only ClamAV** | **Docker, Only YARA** | **Native, All** | **Native, Only ClamAV** | **Native, Only YARA** |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Availability** | ❌ | ❌ | ❌ | ✔️ | ✔️ | ✔️ |
| **Type** | *N/A* | *N/A* | *N/A* | `<boolean = false>` | `<boolean = false>` | `<boolean = false>` |

**(>= v0.21.0)** Whether to clean up. For workflows which run on the GitHub-hosted runner, this is pointless due to each run is a new instance.

### `operate_cleanup_post`

> **🧪 Experimental:** Still under development.

|  | **Docker, All (Default)** | **Docker, Only ClamAV** | **Docker, Only YARA** | **Native, All** | **Native, Only ClamAV** | **Native, Only YARA** |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Availability** | ❌ | ❌ | ❌ | ✔️ | ✔️ | ✔️ |
| **Type** | *N/A* | *N/A* | *N/A* | `<boolean = false>` | `<boolean = false>` | `<boolean = false>` |

**(>= v0.21.0)** Whether to clean up at the post step instead of at the main step.

### `clamav_enable`

|  | **Docker, All (Default)** | **Docker, Only ClamAV** | **Docker, Only YARA** | **Native, All** | **Native, Only ClamAV** | **Native, Only YARA** |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Availability** | ✔️ | ❌ | ❌ | ✔️ | ❌ | ❌ |
| **Type** | `<Boolean = True>` | *N/A* | *N/A* | `<boolean = true>` | *N/A* | *N/A* |

Whether to use ClamAV. When this is `False`/`false`, will ignore inputs:

- [`clamav_update`](#clamav_update)
- [`clamav_unofficialassets_use`](#clamav_unofficialassets_use)
- [`clamav_customassets_directory`](#clamav_customassets_directory)
- [`clamav_customassets_use`](#clamav_customassets_use)

### `clamav_update`

|  | **Docker, All (Default)** | **Docker, Only ClamAV** | **Docker, Only YARA** | **Native, All** | **Native, Only ClamAV** | **Native, Only YARA** |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Availability** | ✔️ | ✔️ | ❌ | ❌ | ❌ | ❌ |
| **Type** | `<Boolean = True>` | `<Boolean = True>` | *N/A* | *N/A* | *N/A* | *N/A* |

Whether to update the ClamAV official assets before scan anything.

> **⚠️ Important:** It is recommended to keep this enable to have the latest ClamAV official assets.

### `clamav_unofficialassets_use`

|  | **Docker, All (Default)** | **Docker, Only ClamAV** | **Docker, Only YARA** | **Native, All** | **Native, Only ClamAV** | **Native, Only YARA** |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Availability** | ✔️ | ✔️ | ❌ | ✔️ | ✔️ | ❌ |
| **Type** | `<RegEx[]>` (PowerShell) | `<RegEx[]>` (PowerShell) | *N/A* | `<RegExp[]>` (NodeJS, Source) | `<RegExp[]>` (NodeJS, Source) | *N/A* |

ClamAV unofficial assets to use, by regular expression of names in the [ClamAV unofficial assets list](https://github.com/hugoalh/scan-virus-ghaction-assets/blob/main/clamav/index.tsv), separate each regular expression per line; By default, all of the ClamAV unofficial assets are not in use.

### `clamav_customassets_directory`

|  | **Docker, All (Default)** | **Docker, Only ClamAV** | **Docker, Only YARA** | **Native, All** | **Native, Only ClamAV** | **Native, Only YARA** |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Availability** | ✔️ | ✔️ | ❌ | ✔️ | ✔️ | ❌ |
| **Type** | `<String>` | `<String>` | *N/A* | `<string>` | `<string>` | *N/A* |

ClamAV custom assets absolute directory path, must be a mapped directory/volume (e.g.: `RUNNER_TEMP`) for Docker entrypoints. When this is not defined, will ignore input [`clamav_customassets_use`](#clamav_customassets_use).

### `clamav_customassets_use`

|  | **Docker, All (Default)** | **Docker, Only ClamAV** | **Docker, Only YARA** | **Native, All** | **Native, Only ClamAV** | **Native, Only YARA** |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Availability** | ✔️ | ✔️ | ❌ | ✔️ | ✔️ | ❌ |
| **Type** | `<RegEx[] = .+>` (PowerShell) | `<RegEx[] = .+>` (PowerShell) | *N/A* | `<RegExp[] = .+>` (NodeJS, Source) | `<RegExp[] = .+>` (NodeJS, Source) | *N/A* |

ClamAV custom assets to use, by regular expression of relative paths in the input [`clamav_customassets_directory`](#clamav_customassets_directory), separate each regular expression per line; By default, all of the ClamAV custom assets are in use.

### `yara_enable`

|  | **Docker, All (Default)** | **Docker, Only ClamAV** | **Docker, Only YARA** | **Native, All** | **Native, Only ClamAV** | **Native, Only YARA** |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Availability** | ✔️ | ❌ | ❌ | ✔️ | ❌ | ❌ |
| **Type** | `<Boolean = False>` | *N/A* | *N/A* | `<boolean = false>` | *N/A* | *N/A* |

Whether to use YARA. When this is `False`/`false`, will ignore inputs:

- [`yara_unofficialassets_use`](#yara_unofficialassets_use)
- [`yara_customassets_directory`](#yara_customassets_directory)
- [`yara_customassets_use`](#yara_customassets_use)

### `yara_unofficialassets_use`

|  | **Docker, All (Default)** | **Docker, Only ClamAV** | **Docker, Only YARA** | **Native, All** | **Native, Only ClamAV** | **Native, Only YARA** |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Availability** | ✔️ | ❌ | ✔️ | ✔️ | ❌ | ✔️ |
| **Type** | `<RegEx[]>` (PowerShell) | *N/A* | `<RegEx[] = .+>` (PowerShell) | `<RegExp[]>` (NodeJS, Source) | *N/A* | `<RegExp[] = .+>` (NodeJS, Source) |

YARA unofficial assets to use, by regular expression of names in the [YARA unofficial assets list](https://github.com/hugoalh/scan-virus-ghaction-assets/blob/main/yara/index.tsv), separate each regular expression per line; By default, all of the YARA unofficial assets are not in use.

### `yara_customassets_directory`

|  | **Docker, All (Default)** | **Docker, Only ClamAV** | **Docker, Only YARA** | **Native, All** | **Native, Only ClamAV** | **Native, Only YARA** |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Availability** | ✔️ | ❌ | ✔️ | ✔️ | ❌ | ✔️ |
| **Type** | `<String>` | *N/A* | `<String>` | `<string>` | *N/A* | `<string>` |

`<String>` YARA custom assets absolute directory path, must be a mapped directory/volume (e.g.: `RUNNER_TEMP`) for Docker entrypoints. When this is not defined, will ignore input [`yara_customassets_use`](#yara_customassets_use).

### `yara_customassets_use`

|  | **Docker, All (Default)** | **Docker, Only ClamAV** | **Docker, Only YARA** | **Native, All** | **Native, Only ClamAV** | **Native, Only YARA** |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Availability** | ✔️ | ❌ | ✔️ | ✔️ | ❌ | ✔️ |
| **Type** | `<RegEx[]>` (PowerShell) | *N/A* | `<RegEx[] = .+>` (PowerShell) | `<RegExp[]>` (NodeJS, Source) | *N/A* | `<RegExp[] = .+>` (NodeJS, Source) |

YARA custom assets to use, by regular expression of relative paths in the input [`yara_customassets_directory`](#yara_customassets_directory), separate each regular expression per line; By default, all of the YARA custom assets are in use.

### `git_integrate`

|  | **Docker, All (Default)** | **Docker, Only ClamAV** | **Docker, Only YARA** | **Native, All** | **Native, Only ClamAV** | **Native, Only YARA** |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Availability** | ✔️ | ✔️ | ✔️ | ✔️ | ✔️ | ✔️ |
| **Type** | `<Boolean = False>` | `<Boolean = False>` | `<Boolean = False>` | `<boolean = false>` | `<boolean = false>` | `<boolean = false>` |

Whether to integrate with Git to perform scan by every commits; Require directory is a Git repository. When this is `False`/`false`, will ignore inputs:

- [`git_ignores`](#git_ignores)
- [`git_lfs`](#git_lfs)
- [`git_limit`](#git_limit)
- [`git_reverse`](#git_reverse)

### `git_ignores`

|  | **Docker, All (Default)** | **Docker, Only ClamAV** | **Docker, Only YARA** | **Native, All** | **Native, Only ClamAV** | **Native, Only YARA** |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Availability** | ✔️ | ✔️ | ✔️ | ✔️ | ✔️ | ✔️ |
| **Type** | `<ScriptBlock>` | `<ScriptBlock>` | `<ScriptBlock>` | `<function>` | `<function>` | `<function>` |

Ignores by the Git commits, by PowerShell script block and must return type of `Boolean` (only return `$True` to able ignore). Ignored Git commits will not be scanned.

The script block should use this pattern in order to receive argument [`GitCommitMeta`](#gitcommitmeta):

```ps1
Param([PSCustomObject]$GitCommitMeta)
<# ... Code for determine ... #>
Return $Result
```

For example, to ignore Git commits made by Dependabot, and ignore Git commits made by OctoCat before 2022/01/01:

```yml
git_ignores: |-
  Param($GitCommitMeta)
  Return (
    $GitCommitMeta.AuthorName -imatch '^dependabot' -or
    ($GitCommitMeta.AuthorDate -lt ([DateTime]::Parse('2022-01-01T00:00:00Z')) -and $GitCommitMeta.AuthorName -imatch '^octocat$')
  )
```

> **⚠️ Important:** PowerShell script block is extremely powerful, which also able to execute malicious actions, user should always take extra review for this input value.

### `git_lfs`

`<Boolean = False>` Whether to process Git LFS files.

### `git_limit`

`<UInt64 = 0>` Limit on how many Git commits will scan, counting is affected by inputs [`git_ignores`](#git_ignores) and [`git_reverse`](#git_reverse); When this value is `0`, means no limit.

> **⚠️ Important:** For actions which run on the GitHub host, it is highly recommended to define this due to the limit of the job execution time (currently is `6 hours`).

### `git_reverse`

`<Boolean = False>` Whether to reverse the scan order of the Git commits.

- **`False`:** From the newest commit to the oldest commit.
- **`True`:** From the oldest commit to the newest commit.

### `ignores_pre`

`<ScriptBlock>` Ignores by the paths, sessions, and tools before the scan, by PowerShell script block and must return type of `Boolean` (only return `$True` to able ignore).

To ignore only by the Git commits, use input [`git_ignores`](#git_ignores) is more efficiency. To ignore only by the tools, use inputs `*_enable` is more efficiency.

The script block should use this pattern in order to receive argument [`ElementPreMeta`](#elementpremeta):

```ps1
Param([PSCustomObject]$ElementPreMeta)
<# ... Code for determine ... #>
Return $Result
```

For example, to ignore path `node_modules`:

```yml
ignores_pre: |-
  Param($ElementPreMeta)
  Return ($ElementPreMeta.Path -imatch '^node_modules[\\/]')
```

> **⚠️ Important:** PowerShell script block is extremely powerful, which also able to execute malicious actions, user should always take extra review for this input value.

### `ignores_post`

`<ScriptBlock>` Ignores by the paths, sessions, symbols (i.e. rules or signatures), and tools after the scan, by PowerShell script block and must return type of `Boolean` (only return `$True` to able ignore).

To ignore only by the paths and/or sessions, use input [`ignores_pre`](#ignores_pre) is more efficiency. To ignore only by the Git commits, use input [`git_ignores`](#git_ignores) is more efficiency. To ignore only by the tools, use inputs `*_enable` is more efficiency.

The script block should use this pattern in order to receive argument [`ElementPostMeta`](#elementpostmeta):

```ps1
Param([PSCustomObject]$ElementPostMeta)
<# ... Code for determine ... #>
Return $Result
```

> **⚠️ Important:**
>
> - PowerShell script block is extremely powerful, which also able to execute malicious actions, user should always take extra review for this input value.
> - It is not recommended to ignore any official symbol due to these rarely have false positives in most cases.

### `found_log`

`<Boolean = True>` Whether to record elements which found virus in the log.

### `found_summary`

`<Boolean = False>` Whether to record elements which found virus in the step summary.

> **⚠️ Important:** If there has many elements which found virus, step summary maybe get truncated and unable to display all of them.

### `statistics_log`

`<Boolean = True>` Whether to record statistics in the log.

### `statistics_summary`

`<Boolean = False>` Whether to record statistics in the step summary.

> **⚠️ Important:** If there has many elements which found virus, step summary maybe get truncated and unable to display statistics.

## 🧩 Input's Script Block Argument Syntax

### `ElementPreMeta`

```ps1
[PSCustomObject]$ElementPreMeta = @{
  Path = [String] # Relative path based on the current working directory without `./` (e.g.: `relative/path/to/file.extension`).
  Session = [PSCustomObject]@{
    Name = [String] # "Current" or Git commit hash.
    GitCommitMeta = $GitCommitMeta -or $Null # Git commit meta, only exists when the session is on a Git commit.
  }
  Tool = [String] # Tool ID.
}
```

### `ElementPostMeta`

```ps1
[PSCustomObject]$ElementPostMeta = @{
  Path = [String] # Relative path based on the current working directory without `./` (e.g.: `relative/path/to/file.extension`).
  Session = [PSCustomObject]@{
    Name = [String] # "Current" or Git commit hash.
    GitCommitMeta = $GitCommitMeta -or $Null # Git commit meta, only exists when the session is on a Git commit.
  }
  Symbol = [String] # Rule or signature.
  Tool = [String] # Tool ID.
}
```

### `GitCommitMeta`

```ps1
[PSCustomObject]$GitCommitMeta = @{
  AuthorDate = [DateTime]
  AuthorEmail = [String]
  AuthorName = [String]
  Body = [String]
  CommitHash = [String]
  CommitterDate = [DateTime]
  CommitterEmail = [String]
  CommitterName = [String]
  Encoding = [String]
  Notes = [String]
  ParentHashes = [String[]]
  ReflogIdentityEmail = [String]
  ReflogIdentityName = [String]
  ReflogSelector = [String]
  ReflogSubject = [String]
  Subject = [String]
  TreeHash = [String]
}
```

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
          uses: "hugoalh/scan-virus-ghaction@v0.20.0"
          with:
            git_ignores: |-
              Param($GitCommitMeta)
              Return (
                $GitCommit.AuthorName -imatch '^dependabot' -or
                ($GitCommit.AuthorDate -lt ([DateTime]::Parse('2022-01-01T00:00:00Z')) -and $GitCommit.AuthorName -imatch '^octocat$')
              )
            git_limit: 100
            ignores_pre: |-
              Param($ElementPreMeta)
              Return ($Meta.Path -imatch '^node_modules[\\/]')
  ```

## 📚 Guide

- GitHub Actions
  - [Enabling debug logging](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/enabling-debug-logging)
- PowerShell
  - [About Script Blocks](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_script_blocks)
