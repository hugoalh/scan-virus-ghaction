#Requires -PSEdition Core
#Requires -Version 7.3
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'datetime',
		'display',
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
[String]$ClamAVUnofficialSignaturesIgnoresAssetsRoot = Join-Path -Path $LocalRoot -ChildPath 'clamav-signatures-ignore-presets'
[String]$ClamAVUnofficialSignaturesIgnoresAssetsIndexFilePath = Join-Path -Path $ClamAVUnofficialSignaturesIgnoresAssetsRoot -ChildPath $IndexFileName
[String]$ClamAVUnofficialSignaturesAssetsRoot = Join-Path -Path $LocalRoot -ChildPath 'clamav-unofficial-signatures'
[String]$ClamAVUnofficialSignaturesAssetsIndexFilePath = Join-Path -Path $ClamAVUnofficialSignaturesAssetsRoot -ChildPath $IndexFileName
[String]$YaraRulesAssetsRoot = Join-Path -Path $LocalRoot -ChildPath 'yara-rules'
[String]$YaraRulesAssetsIndexFilePath = Join-Path -Path $YaraRulesAssetsRoot -ChildPath $IndexFileName
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
			Write-Error -Message "Unable to download the remote assets! $_"
			Exit 1
		}
		Write-GitHubActionsWarning -Message @"
Unable to download the remote assets!
$_
This is fine, but the local assets maybe outdated.
"@
		Return
	}
	Write-GitHubActionsDebug -Message 'Expand the assets package.'
	Try {
		New-Item -Path $PackageTempRoot -ItemType 'Directory' -Force -Confirm:$False |
			Out-Null
		Expand-Archive -LiteralPath $PackageTempFilePath -DestinationPath $PackageTempRoot
	}
	Catch {
		If ($Initial.IsPresent) {
			Write-Error -Message @"
Unable to expand the assets package!
$_
"@
			Exit 1
		}
		Write-GitHubActionsWarning -Message @"
Unable to expand the assets package!
$_
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
		If ($Initial.IsPresent) {
			Write-Error -Message @"
Unable to update the local assets!
$_
"@
		}
		Else {
			Write-GitHubActionsError -Message @"
Unable to update the local assets!
$_
"@
		}
		Exit 1
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
					Path = $_.FullName -ireplace $LocalRootRegEx
					Size = $_.Length
					Flag = $_.PSIsContainer ? 'D' : ''
				} |
					Write-Output
			} |
			Sort-Object -Property 'Path' |
			Format-Table -Property @(
				'Path',
				@{ Expression = 'Size'; Alignment = 'Right' },
				'Flag'
			) -AutoSize -Wrap
		Return
	}
	Write-Host -Object 'Local assets are now up to date.'
}
Function Register-ClamAVUnofficialSignatures {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('SignaturesSelections')][RegEx[]]$SignaturesSelection
	)
	[String[]]$IssuesSignatures = @()
	[PSCustomObject[]]$SignaturesIndexTable = Import-Csv -LiteralPath $ClamAVUnofficialSignaturesAssetsIndexFilePath @ImportCsvParameters_Tsv
	[PSCustomObject[]]$SignaturesOverview = @()
	ForEach ($Signature In $SignaturesIndexTable) {
		[String]$FilePath = Join-Path -Path $ClamAVUnofficialSignaturesAssetsRoot -ChildPath $Signature.Location
		[Boolean]$Exist = Test-Path -LiteralPath $FilePath
		[Boolean]$Select = Test-StringMatchRegExs -Item $Signature.Name -Matchers $SignaturesSelection
		If (!$Exist) {
			Write-GitHubActionsWarning -Message "ClamAV unofficial signature ``$($Signature.Name)`` was indexed but not exist, please create a bug report!"
			$IssuesSignatures += $Signature.Name
		}
		$SignaturesOverview += [PSCustomObject]@{
			Name = $Signature.Name
			Exist = $Exist
			Select = $Select
			Apply = $Exist -and $Select
			DatabaseFileName = $Signature.Location -ireplace '\/', '_'
			FilePath = $FilePath
		}
	}
	Write-NameValue -Name 'All' -Value $SignaturesOverview.Count
	Write-NameValue -Name 'Exist' -Value (
		$SignaturesOverview |
			Where-Object -FilterScript { $_.Exist }
	)
	Write-NameValue -Name 'Select' -Value (
		$SignaturesOverview |
			Where-Object -FilterScript { $_.Select }
	)
	Write-NameValue -Name 'Apply' -Value (
		$SignaturesOverview |
			Where-Object -FilterScript { $_.Apply }
	)
	$SignaturesOverview |
		Format-Table -Property @(
			'Name',
			@{ Expression = 'Exist'; Alignment = 'Right' },
			@{ Expression = 'Select'; Alignment = 'Right' }
		) -AutoSize -Wrap
	[String[]]$SignaturesDestinationFilePaths = @()
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
			Write-GitHubActionsError -Message @"
Unable to apply ClamAV unofficial signature ``$($Signature.Name)``!
$_
"@
			$IssuesSignatures += $Signature.Name
		}
	}
	[String[]]$IssuesIgnores = @()
	[String[]]$IgnoresDestinationFilePaths = @()
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
				Write-GitHubActionsError -Message @"
Unable to apply ClamAV unofficial signature ignore ``$($Ignore.Name)``!
$_
"@
				$IssuesIgnores += $Ignore.Name
			}
		}
	}
	[Hashtable]@{
		IssuesIgnores = $IssuesIgnores
		IssuesSignatures = $IssuesSignatures
		NeedCleanUp = $SignaturesDestinationFilePaths + $IgnoresDestinationFilePaths
	} |
		Write-Output
}
Function Register-YaraRules {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('RulesSelections')][RegEx[]]$RulesSelection
	)
	[String[]]$IssuesRules = @()
	[PSCustomObject[]]$RulesIndexTable = Import-Csv -LiteralPath $YaraRulesAssetsIndexFilePath @ImportCsvParameters_Tsv
	[PSCustomObject[]]$RulesOverview = @()
	ForEach ($Rule In $RulesIndexTable) {
		[String]$FilePath = Join-Path -Path $YaraRulesAssetsRoot -ChildPath $Rule.Location
		[Boolean]$Exist = Test-Path -LiteralPath $FilePath
		[Boolean]$Select = Test-StringMatchRegExs -Item $Rule.Name -Matchers $RulesSelection
		If (!$Exist) {
			Write-GitHubActionsWarning -Message "YARA rule ``$($Rule.Name)`` was indexed but not exist, please create a bug report!"
			$IssuesRules += $Rule.Name
		}
		$RulesOverview += [PSCustomObject]@{
			Name = $Rule.Name
			Exist = $Exist
			Select = $Select
			Apply = $Exist -and $Select
			FilePath = $FilePath
		}
	}
	Write-NameValue -Name 'All' -Value $RulesOverview.Count
	Write-NameValue -Name 'Exist' -Value (
		$RulesOverview |
			Where-Object -FilterScript { $_.Exist }
	)
	Write-NameValue -Name 'Select' -Value (
		$RulesOverview |
			Where-Object -FilterScript { $_.Select }
	)
	Write-NameValue -Name 'Apply' -Value (
		$RulesOverview |
			Where-Object -FilterScript { $_.Apply }
	)
	$RulesOverview |
		Format-Table -Property @(
			'Name',
			@{ Expression = 'Exist'; Alignment = 'Right' },
			@{ Expression = 'Select'; Alignment = 'Right' }
		) -AutoSize -Wrap
	$RulesOverview |
		Where-Object -FilterScript { $_.Apply } |
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
		Write-Warning -Message $_
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
		Write-Warning -Message $_
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
		Write-GitHubActionsFail -Message @"
Unable to get the local assets metadata!
$_
"@
		Exit 1
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
Unable to get the remote assets metadata!
$_
This is fine, but the local assets maybe outdated.
"@
		Return
	}
	Write-NameValue -Name 'Assets_Remote_Compatibility' -Value $RemoteMetadata.Compatibility
	Write-NameValue -Name 'Assets_Remote_Timestamp' -Value (ConvertTo-DateTimeIsoString -InputObject $RemoteAssetsTimestamp)
	Write-GitHubActionsDebug -Message 'Analyze assets.'
	If ($RemoteMetadata.Compatibility -ine $LocalMetadata.Compatibility) {
		Write-GitHubActionsWarning -Message @'
Unable to update the local assets safely!
Local assets' compatibility and remote assets' compatibility are not match.
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
			Write-GitHubActionsWarning -Message "Unexpected exit code ``$LASTEXITCODE`` when update ClamAV via FreshClam! Mostly will not cause critical issues."
		}
	}
	Catch {
		Write-GitHubActionsFail -Message @"
Unexpected issues when update ClamAV via FreshClam!
$_
"@
		Exit 1
	}
	Exit-GitHubActionsLogGroup
}
Export-ModuleMember -Function @(
	'Import-Assets',
	'Register-ClamAVUnofficialSignatures',
	'Register-YaraRules',
	'Restore-ClamAVDatabase',
	'Save-ClamAVDatabase',
	'Update-Assets',
	'Update-ClamAV'
)
