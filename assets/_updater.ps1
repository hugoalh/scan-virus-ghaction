#Requires -PSEdition Core -Version 7.2
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Enter-GitHubActionsLogGroup -Title 'Initialize.'
$CurrentWorkingDirectory = Get-Location
[String[]]$GitIgnores = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '_updater_gitignore.txt') -Encoding 'UTF8NoBOM' |
	Where-Object -FilterScript { $_.Length -igt 0 }
[Hashtable]$ImportCsvParameters_Tsv = @{
	Delimiter = "`t"
	Encoding = 'UTF8NoBOM'
}
[DateTime]$TimeInvoke = Get-Date -AsUTC
[DateTime]$TimeBuffer = $TimeInvoke.AddHours(-1)
[String]$TimeCommit = Get-Date -Date $TimeInvoke -UFormat '%Y-%m-%dT%H:%M:%SZ' -AsUTC
[Boolean]$ShouldPush = $False
Write-Host -Object "Timestamp: $TimeCommit"
Exit-GitHubActionsLogGroup
Write-Host -Object 'Update assets.'
ForEach ($AssetDirectoryName In @('clamav-unofficial', 'yara-unofficial')) {
	[String]$AssetDirectoryPath = Join-Path -Path $PSScriptRoot -ChildPath $AssetDirectoryName
	Write-Host -Object "Read ``$AssetDirectoryName`` asset index."
	[String]$AssetIndexFilePath = Join-Path -Path $AssetDirectoryPath -ChildPath 'index.tsv'
	[PSCustomObject[]]$AssetIndex = Import-Csv -LiteralPath $AssetIndexFilePath @ImportCsvParameters_Tsv
	For ($AssetIndexRow = 0; $AssetIndexRow -ilt $AssetIndex.Count; $AssetIndexRow++) {
		[PSCustomObject]$AssetIndexItem = $AssetIndex[$AssetIndexRow]
		If ($AssetIndexItem.Group.Length -igt 0) {
			Continue
		}
		Enter-GitHubActionsLogGroup -Title "At ``$AssetDirectoryName/$($AssetIndexItem.Name)``."
		If ((Get-Date -Date $AssetIndexItem.Timestamp -AsUTC) -igt $TimeBuffer) {
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
				Invoke-WebRequest -Uri $AssetIndexItem.Remote -UseBasicParsing -MaximumRedirection 5 -MaximumRetryCount 5 -RetryIntervalSec 10 -Method 'Get' -OutFile $OutFilePath
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
		Export-Csv -LiteralPath $AssetIndexFilePath @ImportCsvParameters_Tsv -NoTypeInformation -UseQuotes 'AsNeeded' -Confirm:$False
}
Write-Host -Object 'Conclusion.'
Set-GitHubActionsOutput -Name 'should_push' -Value $ShouldPush.ToString().ToLower()
Set-GitHubActionsOutput -Name 'timestamp' -Value $TimeCommit
