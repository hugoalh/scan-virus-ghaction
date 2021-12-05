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

A GitHub Action to scan virus in the GitHub Action workspace.

### 🛡 Anti Virus Software

- [ClamAV](https://www.clamav.net) (via ClamDScan (`clamdscan`))

### ⚠ Disclaimer

This action does not provide any guarantee that carefully hidden objects will be scanned. Strong endpoint security, access, and code review policies and practices are the most effective way to ensure that malicious files and/or codes are not introduced. False positives maybe also will be happened.

### 🌟 Feature

- 4% to 96% faster than other GitHub Actions with the same purpose, especially when need to scan every Git commits.
- Ability to scan other things, not limited to only Git repository.

## 📚 Documentation

> **⚠ Important:** This documentation is v0.3.0 based; To view other tag's/version's documentation, please visit the [tag/version list](https://github.com/hugoalh/scan-virus-ghaction/tags) and select the correct tag/version.

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

#### `gitdepth`

**\[Optional\]** `<boolean = false>` Also scan every Git commits.

#### `list_elements`

**\[Optional\]** `<(number | string) = "none">` List elements.

- **`0` / `"none"`:** Not list.
- **`1` / `"debug"`:** List at debug level.
- **`2` / `"log"`:** List at log level.

> **⚠ Important:** Enable this list will significantly increase the log size.

#### `list_elementshashes`

**\[Optional\]** `<(number | string) = "none">` List elements' hashes.

- **`0` / `"none"`:** Not list.
- **`1` / `"debug"`:** List at debug level.
- **`2` / `"log"`:** List at log level.

> **⚠ Important:** Enable this list will significantly increase the log size.

#### `list_miscellaneousresults`

**\[Optional\]** `<(number | string) = "debug">` List miscellaneous results.

- **`0` / `"none"`:** Not list.
- **`1` / `"debug"`:** List at debug level.
- **`2` / `"log"`:** List at log level.

> **⚠ Important:** If the result is unexpected, it is always list at error level.

#### `list_scanresults`

**\[Optional\]** `<(number | string) = "debug">` List scan results.

- **`0` / `"none"`:** Not list.
- **`1` / `"debug"`:** List at debug level.
- **`2` / `"log"`:** List at log level.

> **⚠ Important:** If the result is unexpected, it is always list at error level.

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
        uses: "actions/checkout@v2.4.0"
        with:
          fetch-depth: 0
      - name: "Full Scan Repository"
        uses: "hugoalh/scan-virus-ghaction@v0.1.0"
        with:
          gitdepth: "true"
```

### Guide

#### GitHub Actions

- [Enabling debug logging](https://docs.github.com/en/actions/managing-workflow-runs/enabling-debug-logging)
