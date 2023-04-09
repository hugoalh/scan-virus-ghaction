#Requires -PSEdition Core -Version 7.3
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'datetime',
		'display',
		'internal',
		'token'
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
	RetryIntervalSec = 10
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
[String]$YaraUnofficialAssetsRoot = Join-Path -Path $LocalRoot -ChildPath 'yara-unofficial'
[String]$YaraUnofficialAssetsIndexFilePath = Join-Path -Path $YaraUnofficialAssetsRoot -ChildPath $IndexFileName
Function Import-Assets {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Switch]$Build
	)
	Write-GitHubActionsDebug -Message 'Get the assets package path.'
	$TempRoot = [System.IO.Path]::GetTempPath()
	$PackageTempDirectoryPath = Join-Path -Path $TempRoot -ChildPath 'scan-virus-ghaction-assets-main'
	$PackageTempFilePath = Join-Path -Path $TempRoot -ChildPath 'scan-virus-ghaction-assets-main.zip'
	Write-GitHubActionsDebug -Message "Assets_Package_Root: $PackageTempDirectoryPath"
	Write-GitHubActionsDebug -Message "Assets_Package_FilePath: $PackageTempFilePath"
	Write-GitHubActionsDebug -Message 'Download the remote assets.'
	Try {
		Invoke-WebRequest -Uri $RemotePackageFilePath -OutFile $PackageTempFilePath @InvokeWebRequestParameters_Get
	}
	Catch {
		If ($Build.IsPresent) {
			Write-Error -Message "Unable to download the remote assets: $_" -Category 'InvalidResult' -ErrorAction 'Stop'
		}
		Write-GitHubActionsWarning -Message @"
Unable to download the remote assets: $_
This is fine, but the local assets maybe outdated.
"@
		Return
	}
	Write-GitHubActionsDebug -Message 'Expand the assets package.'
	Try {
		Expand-Archive -LiteralPath $PackageTempFilePath -DestinationPath $TempRoot
	}
	Catch {
		If ($Build.IsPresent) {
			Write-Error -Message "Unable to expand the assets package: $_" -Category 'InvalidResult' -ErrorAction 'Stop'
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
		If (!$Build.IsPresent) {
			Remove-Item -LiteralPath $LocalRoot -Recurse -Force -Confirm:$False
		}
		Move-Item -LiteralPath $PackageTempDirectoryPath -Destination $LocalRoot -Confirm:$False
	}
	Catch {
		If ($Build.IsPresent) {
			Write-Error -Message "Unable to update the local assets: $_" -Category 'InvalidResult' -ErrorAction 'Stop'
		}
		Write-GitHubActionsFail -Message "Unable to update the local assets: $_"
	}
	$LocalRootResolve = Resolve-Path -Path $LocalRoot
	[RegEx]$LocalRootRegEx = [RegEx]::Escape("$($LocalRootResolve.Path)/")
	Write-NameValue -Name 'Assets_Local_Root' -Value $LocalRootResolve.Path
	Get-ChildItem -LiteralPath $LocalRoot -Recurse |
		ForEach-Object -Process {
			[PSCustomObject]@{
				Directory = $_.FullName -ireplace $LocalRootRegEx, ''
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
		) -AutoSize -GroupBy 'Directory' |
		Out-String
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
	[PSCustomObject[]]$IndexTable = Import-Csv -LiteralPath $ClamAVUnofficialAssetsIndexFilePath @ImportCsvParameters_Tsv |
		Where-Object -FilterScript { $_.Type -ine 'Group' -and $_.Group.Length -ieq 0 -and $_.Path.Length -igt 0 } |
		ForEach-Object -Process {
			[String]$FilePath = Join-Path -Path $ClamAVUnofficialAssetsRoot -ChildPath $_.Path
			[Boolean]$Exist = Test-Path -LiteralPath $FilePath
			[Boolean]$Select = Test-StringMatchRegExs -Item $_.Name -Matchers $Selection
			[PSCustomObject]@{
				Name = $_.Name
				FilePath = $FilePath
				DatabaseFileName = $_.Path -ireplace '\/', '_'
				ApplyIgnores = $_.ApplyIgnores
				Exist = $Exist
				Select = $Select
				Apply = $Exist -and $Select
			} |
				Write-Output
		}
	Write-NameValue -Name 'All' -Value $IndexTable.Count
	Write-NameValue -Name 'Exist' -Value (
		$IndexTable |
			Where-Object -FilterScript { $_.Exist }
	).Count
	Write-NameValue -Name 'Select' -Value (
		$IndexTable |
			Where-Object -FilterScript { $_.Select }
	).Count
	Write-NameValue -Name 'Apply' -Value (
		$IndexTable |
			Where-Object -FilterScript { $_.Apply }
	).Count
	$IndexTable |
		Format-Table -Property @(
			'Name',
			@{ Expression = 'Exist'; Alignment = 'Right' },
			@{ Expression = 'Select'; Alignment = 'Right' }
		) -AutoSize |
		Out-String
	[String[]]$AssetsApplyPaths = @()
	[String[]]$AssetsApplyIssues = @()
	ForEach ($IndexApply In (
		$IndexTable |
			Where-Object -FilterScript { $_.Apply }
	)) {
		[String]$DestinationFilePath = Join-Path -Path $ClamAVDatabaseRoot -ChildPath $IndexApply.DatabaseFileName
		Try {
			Copy-Item -LiteralPath $IndexApply.FilePath -Destination $DestinationFilePath -Confirm:$False
			$AssetsApplyPaths += $DestinationFilePath
		}
		Catch {
			Write-GitHubActionsError -Message "Unable to apply ClamAV unofficial asset ``$($IndexApply.Name)``: $_"
			$AssetsApplyIssues += $IndexApply.Name
		}
		If ($IndexApply.ApplyIgnores.Length -igt 0) {
			[String[]]$ApplyIgnoresRaw = $IndexApply.ApplyIgnores -isplit ',' |
				ForEach-Object -Process { $_.Trim() } |
				Where-Object -FilterScript { $_.Length -igt 0 }
			ForEach ($ApplyIgnoreRaw In $ApplyIgnoresRaw) {
				[PSCustomObject]$IndexApplyIgnore = $IndexTable |
					Where-Object -FilterScript { $_.Name -ieq $ApplyIgnoreRaw }
					Select-Object -First 1
				[String]$DestinationFilePath = Join-Path -Path $ClamAVDatabaseRoot -ChildPath $IndexApplyIgnore.DatabaseFileName
				If (
					$DestinationFilePath -iin $AssetsApplyPaths -or
					$IndexApplyIgnore.Name -iin $AssetsApplyIssues
				) {
					Continue
				}
				Try {
					Copy-Item -LiteralPath $IndexApplyIgnore.FilePath -Destination $DestinationFilePath -Confirm:$False
					$AssetsApplyPaths += $DestinationFilePath
				}
				Catch {
					Write-GitHubActionsError -Message "Unable to apply ClamAV unofficial asset ``$($IndexApplyIgnore.Name)``: $_"
					$AssetsApplyIssues += $IndexApplyIgnore.Name
				}
			}
		}
	}
	Write-Output -InputObject @{
		ApplyIssues = $AssetsApplyIssues
		ApplyPaths = $AssetsApplyPaths
		IndexTable = $IndexTable
	}
}
Function Register-YaraUnofficialAssets {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Selections')][RegEx[]]$Selection
	)
	[PSCustomObject[]]$IndexTable = Import-Csv -LiteralPath $YaraUnofficialAssetsIndexFilePath @ImportCsvParameters_Tsv |
		Where-Object -FilterScript { $_.Type -ine 'Group' -and $_.Group.Length -ieq 0 -and $_.Path.Length -igt 0 } |
		ForEach-Object -Process {
			[String]$FilePath = Join-Path -Path $YaraUnofficialAssetsRoot -ChildPath $_.Path
			[Boolean]$Exist = Test-Path -LiteralPath $FilePath
			[Boolean]$Select = Test-StringMatchRegExs -Item $_.Name -Matchers $Selection
			[PSCustomObject]@{
				Name = $_.Name
				FilePath = $FilePath
				Exist = $Exist
				Select = $Select
				Apply = $Exist -and $Select
			} |
				Write-Output
		}
	Write-NameValue -Name 'All' -Value $IndexTable.Count
	Write-NameValue -Name 'Exist' -Value (
		$IndexTable |
			Where-Object -FilterScript { $_.Exist }
	).Count
	Write-NameValue -Name 'Select' -Value (
		$IndexTable |
			Where-Object -FilterScript { $_.Select }
	).Count
	Write-NameValue -Name 'Apply' -Value (
		$IndexTable |
			Where-Object -FilterScript { $_.Apply }
	).Count
	$IndexTable |
		Format-Table -Property @(
			'Name',
			@{ Expression = 'Exist'; Alignment = 'Right' },
			@{ Expression = 'Select'; Alignment = 'Right' }
		) -AutoSize |
		Out-String
	Write-Output -InputObject $IndexTable
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
	'Register-ClamAVUnofficialAssets',
	'Register-YaraUnofficialAssets',
	'Update-Assets',
	'Update-ClamAV'
)
