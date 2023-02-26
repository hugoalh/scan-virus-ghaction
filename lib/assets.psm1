#Requires -PSEdition Core
#Requires -Version 7.3
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
[String]$ClamAVUnofficialSignaturesIgnoresAssetsRoot = Join-Path -Path $LocalRoot -ChildPath 'clamav-signatures-ignore-presets'
[String]$ClamAVUnofficialSignaturesIgnoresAssetsIndexFilePath = Join-Path -Path $ClamAVUnofficialSignaturesIgnoresAssetsRoot -ChildPath $IndexFileName
[String]$ClamAVUnofficialSignaturesAssetsRoot = Join-Path -Path $LocalRoot -ChildPath 'clamav-unofficial-signatures'
[String]$ClamAVUnofficialSignaturesAssetsIndexFilePath = Join-Path -Path $ClamAVUnofficialSignaturesAssetsRoot -ChildPath $IndexFileName
[String]$YaraRulesAssetsRoot = Join-Path -Path $LocalRoot -ChildPath 'yara-rules'
[String]$YaraRulesAssetsIndexFilePath = Join-Path -Path $YaraRulesAssetsRoot -ChildPath $IndexFileName
[Hashtable]$ClamAVCacheParameters = @{
	Key = 'scan-virus-ghaction-clamav-database-1'
	LiteralPath = $ClamAVDatabaseRoot
}
Function Import-Assets {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Switch]$Initial
	)
	[String]$PackageTempName = New-RandomToken -Length 32
	[String]$PackageTempRoot = "/tmp/$PackageTempName"# Never use environment variable `RUNNER_TEMP` in here due to it does not exist at image building stage.
	[String]$PackageTempFilePath = "$PackageTempRoot.zip"
	Try {
		Invoke-WebRequest -Uri $RemotePackageFilePath -OutFile $PackageTempFilePath @InvokeWebRequestParameters_Get
	}
	Catch {
		If ($Initial.IsPresent) {
			Write-Error -Message "Unable to download remote assets package! $_"
			Exit 1
		}
		Write-GitHubActionsWarning -Message "Unable to download remote assets package! $_ This is fine, but the local assets maybe outdated."
		Write-Output -InputObject @{
			Success = $False
			Continue = $True
		}
		Return
	}
	Try {
		New-Item -Path $PackageTempRoot -ItemType 'Directory' -Force -Confirm:$False |
			Out-Null
		Expand-Archive -LiteralPath $PackageTempFilePath -DestinationPath $PackageTempRoot
	}
	Catch {
		If ($Initial.IsPresent) {
			Write-Error -Message "Unable to extract remote assets package! $_"
			Exit 1
		}
		Write-GitHubActionsNotice -Message "Unable to extract remote assets package! $_ This is fine, but the local assets maybe outdated."
		Write-Output -InputObject @{
			Success = $False
			Continue = $True
		}
		Return
	}
	Finally {
		Remove-Item -LiteralPath $PackageTempFilePath -Force -Confirm:$False
	}
	Try {
		If (!$Initial.IsPresent) {
			Remove-Item -LiteralPath $LocalRoot -Recurse -Force -Confirm:$False
		}
		Move-Item -LiteralPath (Join-Path -Path $PackageTempRoot -ChildPath 'scan-virus-ghaction-assets-main') -Destination $LocalRoot -Confirm:$False
	}
	Catch {
		If ($Initial.IsPresent) {
			Write-Error -Message "Unable to update local assets package! $_"
			Exit 1
		}
		Write-Output -InputObject @{
			Success = $False
			Continue = $False
			Reason = "Unable to update local assets package! $_"
		}
		Return
	}
	Finally {
		Remove-Item -LiteralPath $PackageTempRoot -Recurse -Force -Confirm:$False
	}
	If ($Initial.IsPresent) {
		[RegEx]$LocalRootRegEx = [RegEx]::Escape("$(Resolve-Path -Path $LocalRoot)/")
		Write-NameValue -Name 'Directory' -Value (Resolve-Path -Path $LocalRoot).Path
		Get-ChildItem -LiteralPath $LocalRoot -Recurse |
			ForEach-Object -Process {
				[PSCustomObject]@{
					Path = $_.FullName -ireplace $LocalRootRegEx
					Length = $_.Length
					IsContainer = $_.PSIsContainer
				} |
					Write-Output
			} |
			Sort-Object -Property 'Path' |
			Format-Table -Property @(
				'Path',
				@{ Expression = 'Length'; Alignment = 'Right' },
				@{ Expression = 'IsContainer'; Alignment = 'Right' }
			) -AutoSize -Wrap
		Return
	}
	Write-Host -Object 'Local assets are now up to date.'
	Write-Output -InputObject @{
		Success = $True
		Continue = $True
	}
}
Function Register-ClamAVUnofficialSignatures {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('SignaturesSelections')][RegEx[]]$SignaturesSelection
	)
	[PSCustomObject[]]$SignaturesIndexTable = Import-Csv -LiteralPath $ClamAVUnofficialSignaturesAssetsIndexFilePath @ImportCsvParameters_Tsv
	[String[]]$IssuesSignatures = @()
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
			DatabaseFileName = $_.Location -ireplace '\/', '_'
			FilePath = $FilePath
		}
	}
	Write-NameValue -Name 'Signatures' -Value "All: $($SignaturesIndexTable.Count); Exist: $(
		$SignaturesOverview |
			Where-Object -FilterScript { $_.Exist }
	); Select: $(
		$SignaturesOverview |
			Where-Object -FilterScript { $_.Select }
	); Apply: $(
		$SignaturesOverview |
			Where-Object -FilterScript { $_.Apply }
	)"
	$SignaturesOverview |
		Format-Table -Property @(
			'Name',
			@{ Expression = 'Exist'; Alignment = 'Right' },
			@{ Expression = 'Select'; Alignment = 'Right' },
			@{ Expression = 'Apply'; Alignment = 'Right' }
		) -AutoSize -Wrap
	[String[]]$NeedCleanUp = @()
	ForEach ($Signature In (
		$SignaturesOverview |
			Where-Object -FilterScript { $_.Apply }
	)) {
		[String]$DestinationFilePath = Join-Path -Path $ClamAVDatabaseRoot -ChildPath $Signature.DatabaseFileName
		Try {
			Copy-Item -LiteralPath $Signature.FilePath -Destination $DestinationFilePath -Confirm:$False
			$NeedCleanUp += $DestinationFilePath
		}
		Catch {
			Write-GitHubActionsError -Message "Unable to apply ClamAV unofficial signature ``$($Signature.Name)``! $_"
			$IssuesSignatures += $Signature.Name
		}
	}
	[Hashtable]@{
		IssuesSignatures = $IssuesSignatures
		NeedCleanUp = $NeedCleanUp
	}
}
Function Register-YaraRules {

}
Function Restore-ClamAVDatabase {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Try {
		Restore-GitHubActionsCache @ClamAVCacheParameters -Timeout 60
	}
	Catch {
		Write-Warning -Message $_
	}
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
	[OutputType([Hashtable])]
	Param ()
	Try {
		[PSCustomObject]$LocalMetadata = Get-Content -LiteralPath $LocalMetadataFilePath -Raw -Encoding 'UTF8NoBOM' |
			ConvertFrom-Json -Depth 100 -NoEnumerate
		[DateTime]$LocalAssetsTimestamp = Get-Date -Date $LocalMetadata.Timestamp -AsUTC
	}
	Catch {
		Write-Output -InputObject @{
			Success = $False
			Continue = $False
			Reason = "Unable to get and parse local assets metadata! $_"
		}
		Return
	}
	Write-NameValue -Name 'Assets_Compatibility_Local' -Value $LocalMetadata.Compatibility
	Write-NameValue -Name 'Assets_Timestamp_Local' -Value (ConvertTo-DateTimeIsoString -InputObject $LocalAssetsTimestamp)
	Try {
		[PSCustomObject]$RemoteMetadata = Invoke-WebRequest -Uri $RemoteMetadataFilePath @InvokeWebRequestParameters_Get |
			Select-Object -ExpandProperty 'Content' |
			ConvertFrom-Json -Depth 100 -NoEnumerate
		[DateTime]$RemoteAssetsTimestamp = Get-Date -Date $RemoteMetadata.Timestamp -AsUTC
	}
	Catch {
		Write-GitHubActionsWarning -Message "Unable to get and parse remote assets metadata! $_ This is fine, but the local assets maybe outdated."
		Write-Output -InputObject @{
			Success = $False
			Continue = $True
		}
		Return
	}
	Write-NameValue -Name 'Assets_Compatibility_Remote' -Value $RemoteMetadata.Compatibility
	Write-NameValue -Name 'Assets_Timestamp_Remote' -Value (ConvertTo-DateTimeIsoString -InputObject $RemoteAssetsTimestamp)
	If ($RemoteMetadata.Compatibility -ine $LocalMetadata.Compatibility) {
		Write-GitHubActionsWarning -Message "Unable to update local assets safely! Local assets' compatibility and remote assets' compatibility are not match. This is fine, but the local assets maybe outdated."
		Write-Output -InputObject @{
			Success = $False
			Continue = $True
		}
		Return
	}
	If ($LocalAssetsTimestamp -ige $RemoteAssetsTimestamp) {
		Write-Host -Object 'Local assets are already up to date.'
		Write-Output -InputObject @{
			Success = $True
			Continue = $True
		}
		Return
	}
	Write-Host -Object 'Need to update local assets.'
	Import-Assets
}
Export-ModuleMember -Function @(
	'Import-Assets',
	'Register-ClamAVUnofficialSignatures',
	'Register-YaraRules',
	'Restore-ClamAVDatabase',
	'Save-ClamAVDatabase',
	'Update-Assets'
)
