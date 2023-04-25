#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
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
	MaximumRedirection = 1
	MaximumRetryCount = 5
	Method = 'Get'
	RetryIntervalSec = 10
	UseBasicParsing = $True
}
[String]$IndexFileName = 'index.tsv'
[ValidateNotNullOrEmpty()][String]$LocalRoot = $Env:GHACTION_SCANVIRUS_PROGRAM_ASSETS
[Uri]$RemoteRoot = 'https://github.com/hugoalh/scan-virus-ghaction-assets'
[Uri]$RemotePackageFilePath = "$RemoteRoot/archive/refs/heads/main.zip"
[ValidateNotNullOrEmpty()][String]$ClamAVDatabaseRoot = $Env:GHACTION_SCANVIRUS_CLAMAV_DATA
[String]$ClamAVUnofficialAssetsRoot = Join-Path -Path $LocalRoot -ChildPath 'clamav-unofficial'
[String]$ClamAVUnofficialAssetsIndexFilePath = Join-Path -Path $ClamAVUnofficialAssetsRoot -ChildPath $IndexFileName
[String]$YaraUnofficialAssetsRoot = Join-Path -Path $LocalRoot -ChildPath 'yara-unofficial'
[String]$YaraUnofficialAssetsIndexFilePath = Join-Path -Path $YaraUnofficialAssetsRoot -ChildPath $IndexFileName
Function Import-Assets {<# Only execute on build stage! #>
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Write-Host -Object 'Import assets.'
	Write-Debug -Message 'Get the assets package path.' -Debug
	$TempRoot = [System.IO.Path]::GetTempPath()
	$PackageTempDirectoryPath = Join-Path -Path $TempRoot -ChildPath 'scan-virus-ghaction-assets-main'
	$PackageTempFilePath = Join-Path -Path $TempRoot -ChildPath 'scan-virus-ghaction-assets-main.zip'
	Write-Verbose -Message "Assets_Local_Root: $LocalRoot" -Verbose
	Write-Verbose -Message "Assets_Package_Root: $PackageTempDirectoryPath" -Verbose
	Write-Verbose -Message "Assets_Package_FilePath: $PackageTempFilePath" -Verbose
	Write-Debug -Message 'Download the remote assets.' -Debug
	Try {
		Invoke-WebRequest -Uri $RemotePackageFilePath -OutFile $PackageTempFilePath @InvokeWebRequestParameters_Get
	}
	Catch {
		Write-Error -Message "Unable to download the remote assets: $_" -Category 'InvalidResult' -ErrorAction 'Stop'
		Return
	}
	Write-Debug -Message 'Expand the assets package.' -Debug
	Try {
		Expand-Archive -LiteralPath $PackageTempFilePath -DestinationPath $TempRoot
	}
	Catch {
		Write-Error -Message "Unable to expand the assets package: $_" -Category 'InvalidResult' -ErrorAction 'Stop'
		Return
	}
	Finally {
		Remove-Item -LiteralPath $PackageTempFilePath -Force -Confirm:$False
	}
	Write-Debug -Message 'Update the local assets.' -Debug
	Try {
		Move-Item -LiteralPath $PackageTempDirectoryPath -Destination $LocalRoot -Confirm:$False
	}
	Catch {
		Write-Error -Message "Unable to update the local assets: $_" -Category 'InvalidResult' -ErrorAction 'Stop'
		Return
	}
	[RegEx]$LocalRootRegEx = [RegEx]::Escape($LocalRoot)
	Get-ChildItem -LiteralPath $LocalRoot -Recurse |
		ForEach-Object -Process { [PSCustomObject]@{
			Path = $_.FullName -ireplace "^$LocalRootRegEx", ''
			Size = $_.Length ?? 0
			Flag = $_.PSIsContainer ? 'D' : ''
		}} |
		Sort-Object -Property @('Path') |
		Format-Table -Property @(
			'Path',
			@{ Expression = 'Size'; Alignment = 'Right' },
			'Flag'
		) -AutoSize |
		Out-String |
		Write-Verbose -Verbose
}
Function Import-NetworkTarget {<# Only execute on main stage! #>
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Uri]$Target
	)
	Enter-GitHubActionsLogGroup -Title "Fetch file ``$Target``."
	[String]$NetworkTargetFilePath = Join-Path -Path $Env:GITHUB_WORKSPACE -ChildPath "$(New-RandomToken).tmp"
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
Function Register-ClamAVUnofficialAssets {<# Only execute on main stage! #>
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Selections')][RegEx[]]$Selection
	)
	[PSCustomObject[]]$IndexTable = Import-Csv -LiteralPath $ClamAVUnofficialAssetsIndexFilePath @ImportCsvParameters_Tsv |
		Where-Object -FilterScript { $_.Type -ine 'Group' -and $_.Group.Length -ieq 0 -and $_.Path.Length -igt 0 } |
		ForEach-Object -Process { [PSCustomObject]@{
			Name = $_.Name
			FilePath = Join-Path -Path $ClamAVUnofficialAssetsRoot -ChildPath $_.Path
			DatabaseFileName = $_.Path -ireplace '\/', '_'
			ApplyIgnores = $_.ApplyIgnores
			Select = Test-StringMatchRegExs -Item $_.Name -Matchers $Selection
		} }
	Write-NameValue -Name 'All' -Value $IndexTable.Count
	Write-NameValue -Name 'Select' -Value (
		$IndexTable |
			Where-Object -FilterScript { $_.Select } |
			Measure-Object |
			Select-Object -ExpandProperty 'Count'
	)
	$IndexTable |
		Format-Table -Property @(
			'Name',
			@{ Expression = 'Select'; Alignment = 'Right' }
		) -AutoSize |
		Out-String |
		Write-Host
	[String[]]$AssetsApplyPaths = @()
	[String[]]$AssetsApplyIssues = @()
	ForEach ($IndexApply In (
		$IndexTable |
			Where-Object -FilterScript { $_.Select }
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
Function Register-YaraUnofficialAssets {<# Only execute on main stage! #>
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Selections')][RegEx[]]$Selection
	)
	[PSCustomObject[]]$IndexTable = Import-Csv -LiteralPath $YaraUnofficialAssetsIndexFilePath @ImportCsvParameters_Tsv |
		Where-Object -FilterScript { $_.Type -ine 'Group' -and $_.Group.Length -ieq 0 -and $_.Path.Length -igt 0 } |
		ForEach-Object -Process { [PSCustomObject]@{
			Name = $_.Name
			FilePath = Join-Path -Path $YaraUnofficialAssetsRoot -ChildPath $_.Path
			Select = Test-StringMatchRegExs -Item $_.Name -Matchers $Selection
		} }
	Write-NameValue -Name 'All' -Value $IndexTable.Count
	Write-NameValue -Name 'Select' -Value (
		$IndexTable |
			Where-Object -FilterScript { $_.Select } |
			Measure-Object |
			Select-Object -ExpandProperty 'Count'
	)
	$IndexTable |
		Format-Table -Property @(
			'Name',
			@{ Expression = 'Select'; Alignment = 'Right' }
		) -AutoSize |
		Out-String |
		Write-Host
	Write-Output -InputObject $IndexTable
}
Function Update-ClamAV {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Switch]$Build
	)
	If ($Build.IsPresent) {
		Write-Host -Object 'Update ClamAV via FreshClam.'
	}
	Else {
		Enter-GitHubActionsLogGroup -Title 'Update ClamAV via FreshClam.'
	}
	Try {
		freshclam --verbose
		If ($LASTEXITCODE -ine 0) {
			Throw "Exit code is $LASTEXITCODE."
		}
	}
	Catch {
		If ($Build.IsPresent) {
			Write-Error -Message "Unexpected issues when update ClamAV via FreshClam: $_" -ErrorAction 'Stop'
			Return
		}
		Write-GitHubActionsWarning -Message @"
Unexpected issues when update ClamAV via FreshClam: $_
This is fine, but the local assets maybe outdated.
"@
	}
	If (!$Build.IsPresent) {
		Exit-GitHubActionsLogGroup
	}
}
Export-ModuleMember -Function @(
	'Import-Assets',
	'Import-NetworkTarget',
	'Register-ClamAVUnofficialAssets',
	'Register-YaraUnofficialAssets',
	'Update-ClamAV'
)
