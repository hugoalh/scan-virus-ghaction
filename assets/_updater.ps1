#Requires -PSEdition Core -Version 7.2
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Enter-GitHubActionsLogGroup -Title 'Initialize.'
$CurrentWorkingDirectory = Get-Location
[String[]]$AssetsDirectoryNames = @('clamav-unofficial', 'yara-unofficial')
[Hashtable]$CsvParameters_Tsv = @{
	Delimiter = "`t"
	Encoding = 'UTF8NoBOM'
}
[String[]]$GitIgnores = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '_updater_gitignore.txt') -Encoding 'UTF8NoBOM' |
	Where-Object -FilterScript { $_.Length -gt 0 }
[Boolean]$ShouldPush = $False
[String]$SymbolIndexFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'symbol.tsv'
[DateTime]$TimeInvoke = Get-Date -AsUTC
[DateTime]$TimeBuffer = $TimeInvoke.AddHours(-1)
[String]$TimeCommit = Get-Date -Date $TimeInvoke -UFormat '%Y-%m-%dT%H:%M:%SZ' -AsUTC
Write-Host -Object "Timestamp: $TimeCommit"
Exit-GitHubActionsLogGroup
Write-Host -Object 'Update assets.'
ForEach ($AssetDirectoryName In $AssetsDirectoryNames) {
	[String]$AssetDirectoryPath = Join-Path -Path $PSScriptRoot -ChildPath $AssetDirectoryName
	Write-Host -Object "Read ``$AssetDirectoryName`` assets index."
	[String]$AssetIndexFilePath = Join-Path -Path $AssetDirectoryPath -ChildPath 'index.tsv'
	[PSCustomObject[]]$AssetIndex = Import-Csv -LiteralPath $AssetIndexFilePath @CsvParameters_Tsv
	For ([UInt64]$AssetIndexRow = 0; $AssetIndexRow -lt $AssetIndex.Count; $AssetIndexRow += 1) {
		[PSCustomObject]$AssetIndexItem = $AssetIndex[$AssetIndexRow]
		If ($AssetIndexItem.Group.Length -gt 0) {
			Continue
		}
		Enter-GitHubActionsLogGroup -Title "At ``$AssetDirectoryName/$($AssetIndexItem.Name)``."
		If ((Get-Date -Date $AssetIndexItem.Timestamp -AsUTC) -gt $TimeBuffer) {
			Write-Host -Object 'No need to update.'
			Exit-GitHubActionsLogGroup
			Continue
		}
		Write-Host -Object 'Need to update.'
		If ($AssetIndexItem.Remote -imatch '^https:\/\/github\.com\/[\da-z_.-]+\/[\da-z_.-]+\.git$') {
			[String]$GitWorkingDirectoryName = $AssetIndexItem.Path -isplit '[\\\/]' |
				Select-Object -First 1
			[String]$GitWorkingDirectoryPath = Join-Path -Path $AssetDirectoryPath -ChildPath $GitWorkingDirectoryName
			If (Test-Path -LiteralPath $GitWorkingDirectoryPath) {
				Write-Host -Object "Remove old assets."
				Remove-Item -LiteralPath $GitWorkingDirectoryPath -Recurse -Force -Confirm:$False
			}
			Write-Host -Object "Update via Git repository ``$($AssetIndexItem.Remote)``."
			Set-Location -LiteralPath $AssetDirectoryPath
			Try {
				Invoke-Expression -Command "git --no-pager clone `"$($AssetIndexItem.Remote)`" `"$GitWorkingDirectoryName`""
			}
			Catch {
				Write-GitHubActionsWarning -Message $_
			}
			Set-Location -LiteralPath $CurrentWorkingDirectory.Path
			Get-ChildItem -LiteralPath $GitWorkingDirectoryPath -Include $GitIgnores -Recurse -Force |
				Remove-Item -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
		}
		Else {
			Write-Host -Object "Update via web request ``$($AssetIndexItem.Remote)``."
			[String]$OutFilePath = Join-Path -Path $AssetDirectoryPath -ChildPath $AssetIndexItem.Path
			[String]$OutFilePathParent = Split-Path -Path $OutFilePath -Parent
			If (!(Test-Path -LiteralPath $OutFilePathParent -PathType 'Container')) {
				$Null = New-Item -Path $OutFilePathParent -ItemType 'Directory' -Confirm:$False
			}
			Try {
				Invoke-WebRequest -Uri $AssetIndexItem.Remote -MaximumRedirection 1 -MaximumRetryCount 5 -RetryIntervalSec 10 -Method 'Get' -OutFile $OutFilePath
			}
			Catch {
				Write-GitHubActionsWarning -Message $_
			}
		}
		$AssetIndex[$AssetIndexRow].Timestamp = $TimeCommit
		$ShouldPush = $True
		Exit-GitHubActionsLogGroup
	}
	Write-Host -Object "Update ``$AssetDirectoryName`` asset index."
	$AssetIndex |
		Export-Csv -LiteralPath $AssetIndexFilePath @CsvParameters_Tsv -UseQuotes 'AsNeeded' -Confirm:$False
}
Write-Host -Object 'Verify assets index; Generate symbol list.'
[String[]]$IndexIssuesFileNotExist = @()
[String[]]$IndexIssuesFileNotRecord = @()
[PSCustomObject[]]$SymbolIndex = @()
ForEach ($AssetDirectoryName In $AssetsDirectoryNames) {
	[String]$AssetDirectoryPath = Join-Path -Path $PSScriptRoot -ChildPath $AssetDirectoryName
	Write-Host -Object "Read ``$AssetDirectoryName`` asset index."
	[String]$AssetIndexFilePath = Join-Path -Path $AssetDirectoryPath -ChildPath 'index.tsv'
	[PSCustomObject[]]$AssetIndex = Import-Csv -LiteralPath $AssetIndexFilePath @CsvParameters_Tsv
	For ([UInt64]$AssetIndexRow = 0; $AssetIndexRow -lt $AssetIndex.Count; $AssetIndexRow += 1) {
		[PSCustomObject]$AssetIndexItem = $AssetIndex[$AssetIndexRow]
		If ($AssetIndexItem.Type -ieq 'Group') {
			Continue
		}
		[String]$FilePath = Join-Path -Path $AssetDirectoryPath -ChildPath $AssetIndexItem.Path
		If (Test-Path -LiteralPath $FilePath -PathType 'Leaf') {
			Switch -RegEx ($AssetIndexItem.Path) {
				'\.(?:cdb|nd[bu])$' {
					[String[]]$Symbols = Get-Content -LiteralPath $FilePath -Encoding 'UTF8NoBOM' |
						Where-Object -FilterScript { $_.Length -gt 0 } |
						ForEach-Object -Process {
							$_ -isplit ':' |
								Select-Object -Index 0
						}
					Break
				}
				'\.(?:h[ds][bu]|imp|m[ds][bu])$' {
					[String[]]$Symbols = Get-Content -LiteralPath $FilePath -Encoding 'UTF8NoBOM' |
						Where-Object -FilterScript { $_.Length -gt 0 } |
						ForEach-Object -Process {
							$_ -isplit ':' |
								Select-Object -Index 2
						}
					Break
				}
				'\.(?:idb|ld[bu])$' {
					[String[]]$Symbols = Get-Content -LiteralPath $FilePath -Encoding 'UTF8NoBOM' |
						Where-Object -FilterScript { $_.Length -gt 0 } |
						ForEach-Object -Process {
							$_ -isplit ';' |
								Select-Object -Index 0
						}
					Break
				}
				'\.ign2?$' {
					[String[]]$Symbols = @()
					Break
				}
				'\.yara?$' {
					[String[]]$Symbols = Get-Content -LiteralPath $FilePath -Encoding 'UTF8NoBOM' |
						Where-Object -FilterScript { $_ -imatch '^rule .+(?: \{)?$' } |
						ForEach-Object -Process {
							$_ -isplit ' ' |
								Select-Object -Index 1
						}
					Break
				}
				Default {
					[String[]]$Symbols = @()
					Break
				}
			}
			ForEach ($Symbol In $Symbols) {
				$SymbolIndex += [PSCustomObject]@{
					Type = $AssetIndexItem.Type
					Name = $AssetIndexItem.Name
					Path = $AssetIndexItem.Path
					Symbol = $Symbol
				}
			}
		}
		Else {
			$IndexIssuesFileNotExist += "$AssetDirectoryName/$($AssetIndexItem.Name)"
		}
	}
	If ($AssetDirectoryName -ieq 'yara-unofficial') {
		ForEach ($ElementFullName In (
			Get-ChildItem -LiteralPath @(
				(Join-Path -Path $AssetDirectoryPath -ChildPath 'bartblaze' -AdditionalChildPath @('rules')),
				(Join-Path -Path $AssetDirectoryPath -ChildPath 'neo23x0' -AdditionalChildPath @('yara'))
			) -Include @('*.yar', '*.yara') -Recurse -File |
				Select-Object -ExpandProperty 'FullName'
		)) {
			[String]$ElementRelativeName = $ElementFullName -ireplace "^$([RegEx]::Escape($AssetDirectoryPath))[\\\/]", '' -ireplace '[\\\/]', '/'
			If ($AssetIndex.Path -inotcontains $ElementRelativeName) {
				$IndexIssuesFileNotRecord += $ElementRelativeName
			}
		}
	}
}
$SymbolIndex |
	Export-Csv -LiteralPath $SymbolIndexFilePath @CsvParameters_Tsv -UseQuotes 'AsNeeded' -Confirm:$False
If ($IndexIssuesFileNotExist.Count -gt 0) {
	Write-GitHubActionsWarning -Message @"
File Not Exist [$($IndexIssuesFileNotExist.Count)]:

$(
	$IndexIssuesFileNotExist |
		Sort-Object |
		Join-String -Separator "`n" -FormatString '- `{0}`'
)
"@
}
If ($IndexIssuesFileNotRecord -gt 0) {
	Write-GitHubActionsWarning -Message @"
File Not Record [$($IndexIssuesFileNotRecord.Count)]:

$(
	$IndexIssuesFileNotRecord |
		Sort-Object |
		Join-String -Separator "`n" -FormatString '- `{0}`'
)
"@
}
Write-Host -Object 'Conclusion.'
Set-GitHubActionsOutput -Name 'should_push' -Value $ShouldPush.ToString().ToLower()
Set-GitHubActionsOutput -Name 'timestamp' -Value $TimeCommit
