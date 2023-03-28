#Requires -PSEdition Core -Version 7.3
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'datetime',
		'display',
		'token',
		'utility'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
[Hashtable]$ImportCsvParameters_Tsv = @{
	Delimiter = "`t"
	Encoding = 'UTF8NoBOM'
}
[Hashtable]$InvokeWebRequestParameters_Get = @{
	MaximumRedirection = 5
	MaximumRetryCount = 5
	Method = 'Get'
	RetryIntervalSec = 5
	UseBasicParsing = $True
}
[String]$IndexFileName = 'index.tsv'
[String]$MetadataFileName = 'metadata.json'
[String]$LocalRoot = Join-Path -Path $PSScriptRoot -ChildPath '../assets'
[String]$LocalMetadataFilePath = Join-Path -Path $LocalRoot -ChildPath $MetadataFileName
[Uri]$RemoteRoot = 'https://github.com/hugoalh/scan-virus-ghaction-assets'
[Uri]$RemoteMetadataFilePath = "$RemoteRoot/raw/main/$MetadataFileName"
[Uri]$RemotePackageFilePath = "$RemoteRoot/archive/refs/heads/main.zip"
[String]$ClamAVDatabaseRoot = '/var/lib/clamav'
[String]$ClamAVUnofficialAssetsRoot = Join-Path -Path $LocalRoot -ChildPath 'clamav-unofficial'
[String]$ClamAVUnofficialAssetsIndexFilePath = Join-Path -Path $ClamAVUnofficialAssetsRoot -ChildPath $IndexFileName
[String]$YaraAssetsRoot = Join-Path -Path $LocalRoot -ChildPath 'yara'
[String]$YaraAssetsIndexFilePath = Join-Path -Path $YaraAssetsRoot -ChildPath $IndexFileName
[Hashtable]$ClamAVCacheParameters = @{
	Key = 'scan-virus-ghaction-database-clamav-1'
	LiteralPath = $ClamAVDatabaseRoot
}
Function Import-Assets {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Switch]$Initial
	)
	Write-GitHubActionsDebug -Message 'Generate the assets package path.'
	$PackageTempFilePath = New-TemporaryFile
	$PackageTempRoot = Split-Path -LiteralPath $PackageTempFilePath
	Write-GitHubActionsDebug -Message "$($PSStyle.Bold)Assets_Package_Root: $($PSStyle.Reset)$($PackageTempRoot)"
	Write-GitHubActionsDebug -Message "$($PSStyle.Bold)Assets_Package_FilePath: $($PSStyle.Reset)$($PackageTempFilePath.FullName)"
	Write-GitHubActionsDebug -Message 'Download the remote assets.'
	Try {
		Invoke-WebRequest -Uri $RemotePackageFilePath -OutFile $PackageTempFilePath @InvokeWebRequestParameters_Get
	}
	Catch {
		If ($Initial.IsPresent) {
			Write-GitHubActionsFail -Message "Unable to download the remote assets: $_"
		}
		Write-GitHubActionsWarning -Message @"
Unable to download the remote assets: $_
This is fine, but the local assets maybe outdated.
"@
		Return
	}
	Write-GitHubActionsDebug -Message 'Expand the assets package.'
	Try {
		$Null = New-Item -Path $PackageTempRoot -ItemType 'Directory' -Force -Confirm:$False
		Expand-Archive -LiteralPath $PackageTempFilePath -DestinationPath $PackageTempRoot
	}
	Catch {
		If ($Initial.IsPresent) {
			Write-GitHubActionsFail -Message "Unable to expand the assets package: $_"
		}
		Write-GitHubActionsWarning -Message @"
Unable to expand the assets package: $_
This is fine, but the local assets maybe outdated.
"@
		Return
	}
	Finally {
		Remove-Item -LiteralPath $PackageTempFilePath -Force -Confirm:$False
	}
	Write-GitHubActionsDebug -Message 'Update the local assets.'
	Try {
		If (!$Initial.IsPresent) {
			Remove-Item -LiteralPath $LocalRoot -Recurse -Force -Confirm:$False
		}
		Move-Item -LiteralPath (Join-Path -Path $PackageTempRoot -ChildPath 'scan-virus-ghaction-assets-main') -Destination $LocalRoot -Confirm:$False
	}
	Catch {
		Write-GitHubActionsFail -Message "Unable to update the local assets: $_"
	}
	Finally {
		Remove-Item -LiteralPath $PackageTempRoot -Recurse -Force -Confirm:$False
	}
	If ($Initial.IsPresent) {
		$LocalRootResolve = Resolve-Path -Path $LocalRoot
		[RegEx]$LocalRootRegEx = [RegEx]::Escape("$($LocalRootResolve.Path)/")
		Write-NameValue -Name 'Assets_Local_Root' -Value $LocalRootResolve.Path
		Get-ChildItem -LiteralPath $LocalRoot -Recurse |
			ForEach-Object -Process {
				[PSCustomObject]@{
					Directory = $_.Directory.FullName -ireplace $LocalRootRegEx, ''
					Name = $_.Name
					Size = $_.Length
					Flag = $_.PSIsContainer ? 'D' : ''
				} |
					Write-Output
			} |
			Sort-Object -Property @('Directory', 'Name') |
			Format-Table -Property @(
				'Name',
				@{ Expression = 'Size'; Alignment = 'Right' },
				'Flag'
			) -AutoSize -Wrap -GroupBy 'Directory'
		Return
	}
	Write-Host -Object 'Local assets are now up to date.'
}
Function Import-NetworkTarget {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Uri]$Target
	)
	Enter-GitHubActionsLogGroup -Title "Fetch file ``$Target``."
	[String]$NetworkTargetFilePath = Join-Path -Path $Env:GITHUB_WORKSPACE -ChildPath (New-RandomToken)
	Try {
		Invoke-WebRequest -Uri $Target -OutFile $NetworkTargetFilePath @InvokeWebRequestParameters_Get
	}
	Catch {
		Write-GitHubActionsError -Message "Unable to fetch file ``$Target``: $_"
		Return
	}
	Finally {
		Exit-GitHubActionsLogGroup
	}
	Write-Output -InputObject $NetworkTargetFilePath
}
Function Register-ClamAVUnofficialAssets {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Selections')][RegEx[]]$Selection
	)
	[PSCustomObject[]]$IndexTable = Import-Csv -LiteralPath $ClamAVAssetsIndexFilePath @ImportCsvParameters_Tsv
	[PSCustomObject[]]$Overview = @()
	ForEach ($Row In $IndexTable) {
		[String]$FilePath = Join-Path -Path $ClamAVUnofficialAssetsRoot -ChildPath $Row.Path
		[Boolean]$Exist = Test-Path -LiteralPath $FilePath
		[Boolean]$Select = Test-StringMatchRegExs -Item $Row.Name -Matchers $Selection
		$Overview += [PSCustomObject]@{
			Name = $Row.Name
			Exist = $Exist
			Select = $Select
			Apply = $Exist -and $Select
			DatabaseFileName = $Row.Path -ireplace '\/', '_'
			FilePath = $FilePath
		}
	}
	[String[]]$AssetsNotExist = $Overview |
		Where-Object -FilterScript { !$_.Exist } |
		Select-Object -ExpandProperty 'Name'
	If ($AssetsNotExist.Count -igt 0) {
		Write-GitHubActionsWarning -Message @"
Some of the ClamAV unofficial assets were indexed but not exist, please create a bug report!
$(
	$AssetsNotExist
		Join-String -Separator ', ' -FormatString '`{0}`'
)
"@
	}
	Write-NameValue -Name 'All' -Value $Overview.Count
	Write-NameValue -Name 'Exist' -Value (
		$Overview |
			Where-Object -FilterScript { $_.Exist }
	).Count
	Write-NameValue -Name 'Select' -Value (
		$Overview |
			Where-Object -FilterScript { $_.Select }
	).Count
	Write-NameValue -Name 'Apply' -Value (
		$Overview |
			Where-Object -FilterScript { $_.Apply }
	).Count
	$Overview |
		Format-Table -Property @(
			'Name',
			@{ Expression = 'Exist'; Alignment = 'Right' },
			@{ Expression = 'Select'; Alignment = 'Right' }
		) -AutoSize -Wrap
	[String[]]$SignaturesDestinationFilePaths = @()
	[String[]]$IssuesSignaturesApply = @()
	ForEach ($Signature In (
		$SignaturesOverview |
			Where-Object -FilterScript { $_.Apply }
	)) {
		[String]$DestinationFilePath = Join-Path -Path $ClamAVDatabaseRoot -ChildPath $Signature.DatabaseFileName
		Try {
			Copy-Item -LiteralPath $Signature.FilePath -Destination $DestinationFilePath -Confirm:$False
			$SignaturesDestinationFilePaths += $DestinationFilePath
		}
		Catch {
			Write-GitHubActionsError -Message "Unable to apply ClamAV unofficial signature ``$($Signature.Name)``: $_"
			$IssuesSignaturesApply += $Signature.Name
		}
	}
	[String[]]$IgnoresDestinationFilePaths = @()
	[String[]]$IssuesIgnores = @()
	If ($SignaturesDestinationFilePaths -igt 0) {
		[PSCustomObject[]]$IgnoresIndexTable = Import-Csv -LiteralPath $ClamAVUnofficialSignaturesIgnoresAssetsIndexFilePath @ImportCsvParameters_Tsv
		ForEach ($Ignore In $IgnoresIndexTable) {
			[String]$FilePath = Join-Path -Path $ClamAVUnofficialSignaturesIgnoresAssetsRoot -ChildPath $Ignore.Location
			[String]$DestinationFilePath = Join-Path -Path $ClamAVDatabaseRoot -ChildPath ($Ignore.Location -ireplace '\/', '_')
			Try {
				Copy-Item -LiteralPath $FilePath -Destination $DestinationFilePath -Confirm:$False
				$IgnoresDestinationFilePaths += $DestinationFilePath
			}
			Catch {
				Write-GitHubActionsError -Message "Unable to apply ClamAV unofficial signature ignore ``$($Ignore.Name)``: $_"
				$IssuesIgnores += $Ignore.Name
			}
		}
	}
	[Hashtable]@{
		IssuesIgnores = $IssuesIgnores
		IssuesSignaturesApply = $IssuesSignaturesApply
		IssuesSignaturesNotExist = $IssuesSignaturesNotExist
		NeedCleanUp = $SignaturesDestinationFilePaths + $IgnoresDestinationFilePaths
	} |
		Write-Output
}
Function Register-YaraRules {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('RulesSelections')][RegEx[]]$RulesSelection
	)
	[PSCustomObject[]]$RulesIndexTable = Import-Csv -LiteralPath $YaraRulesAssetsIndexFilePath @ImportCsvParameters_Tsv
	[PSCustomObject[]]$RulesOverview = @()
	ForEach ($Rule In $RulesIndexTable) {
		[String]$FilePath = Join-Path -Path $YaraRulesAssetsRoot -ChildPath $Rule.Location
		[Boolean]$Exist = Test-Path -LiteralPath $FilePath
		[Boolean]$Select = Test-StringMatchRegExs -Item $Rule.Name -Matchers $RulesSelection
		$RulesOverview += [PSCustomObject]@{
			Name = $Rule.Name
			Exist = $Exist
			Select = $Select
			Apply = $Exist -and $Select
			FilePath = $FilePath
		}
	}
	[String[]]$IssuesRulesNotExist = $RulesOverview |
		Where-Object -FilterScript { !$_.Exist } |
		Select-Object -ExpandProperty 'Name'
	If ($IssuesRulesNotExist.Count -igt 0) {
		Write-GitHubActionsWarning -Message @"
Some of the YARA rules were indexed but not exist, please create a bug report!
$(
	$IssuesRulesNotExist
		Join-String -Separator ', ' -FormatString '`{0}`'
)
"@
	}
	Write-NameValue -Name 'All' -Value $RulesOverview.Count
	Write-NameValue -Name 'Exist' -Value (
		$RulesOverview |
			Where-Object -FilterScript { $_.Exist }
	).Count
	Write-NameValue -Name 'Select' -Value (
		$RulesOverview |
			Where-Object -FilterScript { $_.Select }
	).Count
	Write-NameValue -Name 'Apply' -Value (
		$RulesOverview |
			Where-Object -FilterScript { $_.Apply }
	).Count
	$RulesOverview |
		Format-Table -Property @(
			'Name',
			@{ Expression = 'Exist'; Alignment = 'Right' },
			@{ Expression = 'Select'; Alignment = 'Right' }
		) -AutoSize -Wrap
	[Hashtable]@{
		IssuesRulesNotExist = $IssuesRulesNotExist
		Select = $RulesOverview |
			Where-Object -FilterScript { $_.Apply }
	} |
		Write-Output
}
Function Restore-ClamAVDatabase {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Enter-GitHubActionsLogGroup -Title 'Restore ClamAV database.'
	Try {
		Restore-GitHubActionsCache @ClamAVCacheParameters -Timeout 60
	}
	Catch {
		Write-GitHubActionsNotice -Message $_
	}
	Exit-GitHubActionsLogGroup
}
Function Save-ClamAVDatabase {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Try {
		Save-GitHubActionsCache @ClamAVCacheParameters
	}
	Catch {
		Write-GitHubActionsNotice -Message $_
	}
}
Function Update-Assets {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Write-GitHubActionsDebug -Message 'Get the local assets metadata.'
	Try {
		[PSCustomObject]$LocalMetadata = Get-Content -LiteralPath $LocalMetadataFilePath -Raw -Encoding 'UTF8NoBOM' |
			ConvertFrom-Json -Depth 100 -NoEnumerate
		[DateTime]$LocalAssetsTimestamp = Get-Date -Date $LocalMetadata.Timestamp -AsUTC
	}
	Catch {
		Write-GitHubActionsFail -Message "Unable to get the local assets metadata: $_"
	}
	Write-NameValue -Name 'Assets_Local_Compatibility' -Value $LocalMetadata.Compatibility
	Write-NameValue -Name 'Assets_Local_Timestamp' -Value (ConvertTo-DateTimeIsoString -InputObject $LocalAssetsTimestamp)
	Write-GitHubActionsDebug -Message 'Get the remote assets metadata.'
	Try {
		[PSCustomObject]$RemoteMetadata = Invoke-WebRequest -Uri $RemoteMetadataFilePath @InvokeWebRequestParameters_Get |
			Select-Object -ExpandProperty 'Content' |
			ConvertFrom-Json -Depth 100 -NoEnumerate
		[DateTime]$RemoteAssetsTimestamp = Get-Date -Date $RemoteMetadata.Timestamp -AsUTC
	}
	Catch {
		Write-GitHubActionsWarning -Message @"
Unable to get the remote assets metadata: $_
This is fine, but the local assets maybe outdated.
"@
		Return
	}
	Write-NameValue -Name 'Assets_Remote_Compatibility' -Value $RemoteMetadata.Compatibility
	Write-NameValue -Name 'Assets_Remote_Timestamp' -Value (ConvertTo-DateTimeIsoString -InputObject $RemoteAssetsTimestamp)
	Write-GitHubActionsDebug -Message 'Analyze assets.'
	If ($RemoteMetadata.Compatibility -ine $LocalMetadata.Compatibility) {
		Write-GitHubActionsWarning -Message @'
Unable to update the local assets safely: Local assets' compatibility and remote assets' compatibility are not match.
This is fine, but the local assets maybe outdated.
'@
		Return
	}
	If ($LocalAssetsTimestamp -ige $RemoteAssetsTimestamp) {
		Write-Host -Object 'The local assets are already up to date.'
		Return
	}
	Write-Host -Object 'Need to update the local assets.'
	Import-Assets
}
Function Update-ClamAV {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Enter-GitHubActionsLogGroup -Title 'Update ClamAV via FreshClam.'
	Try {
		freshclam
		If ($LASTEXITCODE -ine 0) {
			Write-GitHubActionsWarning -Message @"
Unexpected issues when update ClamAV via FreshClam with exit code ``$LASTEXITCODE``: $_
This is fine, but the local assets maybe outdated.
"@
		}
	}
	Catch {
		Write-GitHubActionsWarning -Message @"
Unexpected issues when update ClamAV via FreshClam: $_
This is fine, but the local assets maybe outdated.
"@
	}
	Exit-GitHubActionsLogGroup
}
Export-ModuleMember -Function @(
	'Import-Assets',
	'Import-NetworkTarget',
	'Register-ClamAVUnofficialSignatures',
	'Register-YaraRules',
	'Restore-ClamAVDatabase',
	'Save-ClamAVDatabase',
	'Update-Assets',
	'Update-ClamAV'
)
