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
[Hashtable]$InvokeWebGetRequestParameters = @{
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
Function Import-Assets {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Switch]$IsInitial
	)
	[String]$PackageTempName = (New-Guid).Guid -replace '-', ''
	[String]$PackageTempRoot = Join-Path -Path $Env:TEMP -ChildPath $PackageTempName
	[String]$PackageTempFilePath = "$PackageTempRoot.zip"
	Try {
		Invoke-WebRequest -Uri $RemotePackageFilePath -OutFile $PackageTempFilePath @InvokeWebGetRequestParameters
	}
	Catch {
		If ($IsInitial.IsPresent) {
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
		If ($IsInitial.IsPresent) {
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
		If (!$IsInitial.IsPresent) {
			Remove-Item -LiteralPath $LocalRoot -Recurse -Force -Confirm:$False
		}
		Move-Item -LiteralPath (Join-Path -Path $PackageTempRoot -ChildPath 'scan-virus-ghaction-assets-main') -Destination $LocalRoot -Confirm:$False
	}
	Catch {
		If ($IsInitial.IsPresent) {
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
	Write-Host -Object 'Local assets are now up to date.'
	Write-Output -InputObject @{
		Success = $True
		Continue = $True
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
	Write-NameValue -Name 'Assets_Timestamp_Local' -Value (ConvertTo-DateTimeISOString -InputObject $LocalAssetsTimestamp)
	Try {
		[PSCustomObject]$RemoteMetadata = Invoke-WebRequest -Uri $RemoteMetadataFilePath @InvokeWebGetRequestParameters |
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
	Write-NameValue -Name 'Assets_Timestamp_Remote' -Value (ConvertTo-DateTimeISOString -InputObject $RemoteAssetsTimestamp)
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
	'Update-Assets'
)
