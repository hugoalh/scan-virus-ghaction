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
[Hashtable]$InvokeWebRequestParameters_Get = @{
	MaximumRedirection = 5
	MaximumRetryCount = 5
	Method = 'Get'
	RetryIntervalSec = 5
	UseBasicParsing = $True
}
[String]$MetadataFileName = 'metadata.json'
[String]$LocalRoot = Join-Path -Path $PSScriptRoot -ChildPath '../assets'
[String]$LocalMetadataFilePath = Join-Path -Path $LocalRoot -ChildPath $MetadataFileName
[Uri]$RemoteRoot = 'https://github.com/hugoalh/scan-virus-ghaction-assets'
[Uri]$RemoteMetadataFilePath = "$RemoteRoot/raw/main/$MetadataFileName"
[Uri]$RemotePackageFilePath = "$RemoteRoot/archive/refs/heads/main.zip"
[String]$ClamAVDatabaseRoot = '/var/lib/clamav'
[String]$ClamAVUnofficialSignaturesIgnoresAssetsRoot = Join-Path -Path $LocalRoot -ChildPath 'clamav-signatures-ignore-presets'
[String[]]$ClamAVUnofficialSignaturesIgnores = @(
	'sigwhitelist.ign2'
)
[String]$ClamAVUnofficialSignaturesAssetsRoot = Join-Path -Path $LocalRoot -ChildPath 'clamav-unofficial-signatures'
[String]$YaraRulesAssetsRoot = Join-Path -Path $LocalRoot -ChildPath 'yara-rules'
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
	[String]$PackageTempRoot = "/tmp/$PackageTempName"
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
		Get-ChildItem -LiteralPath $LocalRoot -Recurse |
			Format-Table -Property @('Name', 'Length', 'PSIsContainer') -Wrap -GroupBy 'Directory'
		Return
	}
	Write-Host -Object 'Local assets are now up to date.'
	Write-Output -InputObject @{
		Success = $True
		Continue = $True
	}
}
Function Restore-ClamAVDatabase {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Restore-GitHubActionsCache @ClamAVCacheParameters -Timeout 60
}
Function Save-ClamAVDatabase {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Save-GitHubActionsCache @ClamAVCacheParameters
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
	'Restore-ClamAVDatabase',
	'Save-ClamAVDatabase',
	'Update-Assets'
)
