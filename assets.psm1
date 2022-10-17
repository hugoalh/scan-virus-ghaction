#Requires -PSEdition Core
#Requires -Version 7.2
Import-Module -Name @(
	'hugoalh.GitHubActionsToolkit',
	(Join-Path -Path $PSScriptRoot -ChildPath 'utility.psm1')
) -Scope 'Local'
[Hashtable]$DateTimeISOParameters = @{
	AsUTC = $True
	UFormat = '%Y-%m-%dT%H:%M:%SZ'
}
[Hashtable]$InvokeWebGetRequestParameters = @{
	MaximumRedirection = 5
	MaximumRetryCount = 5
	Method = 'Get'
	RetryIntervalSec = 5
	UseBasicParsing = $True
}
[String]$AssetsLocalRoot = Join-Path -Path $PSScriptRoot -ChildPath 'assets'
[String]$AssetsLocalOutdatedMessage = 'This is fine, but local assets maybe outdated.'
[String]$AssetsRemoteRoot = 'https://github.com/hugoalh/scan-virus-ghaction-assets'
[String]$AssetsRemotePackage = "$AssetsRemoteRoot/archive/refs/heads/main.tar.gz"
[String]$AssetsRemoteOutFileFullName = Join-Path -Path $PSScriptRoot -ChildPath 'assets-remote.tar.gz'
[String]$AssetsRemoteExtractRoot = Join-Path -Path $PSScriptRoot -ChildPath 'assets-remote'
[String]$AssetsMetadataName = 'metadata.json'
Function Update-GitHubActionScanVirusAssets {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Try {
		[PSCustomObject]$LocalMetadata = Get-Content -LiteralPath (Join-Path -Path $AssetsLocalRoot -ChildPath $AssetsMetadataName) -Raw -Encoding 'UTF8NoBOM' |
			ConvertFrom-Json -Depth 100
		[DateTime]$LocalAssetsTimestamp = Get-Date -Date $LocalMetadata.Timestamp -AsUTC
	}
	Catch {
		Throw "Unable to get and parse local assets metadata! Local assets maybe modified unexpectedly. $_"
	}
	Write-NameValue -Name 'Local Assets Compatibility' -Value $LocalMetadata.Compatibility
	Write-NameValue -Name 'Local Assets Timestamp' -Value (Get-Date -Date $LocalAssetsTimestamp @DateTimeISOParameters)
	Try {
		[PSCustomObject]$RemoteMetadata = Invoke-WebRequest -Uri "$AssetsRemoteRoot/raw/main/$AssetsMetadataName" @InvokeWebGetRequestParameters |
			Select-Object -ExpandProperty 'Content' |
			Join-String -Separator "`n" |
			ConvertFrom-Json -Depth 100
		[DateTime]$RemoteAssetsTimestamp = Get-Date -Date $RemoteMetadata.Timestamp -AsUTC
	}
	Catch {
		Write-GitHubActionsWarning -Message "Unable to get and parse remote assets metadata! $_ $AssetsLocalOutdatedMessage"
		Return
	}
	Write-NameValue -Name 'Remote Assets Compatibility' -Value $RemoteMetadata.Compatibility
	Write-NameValue -Name 'Remote Assets Timestamp' -Value (Get-Date -Date $RemoteAssetsTimestamp @DateTimeISOParameters)
	If ($RemoteMetadata.Compatibility -ine $LocalMetadata.Compatibility) {
		Write-GitHubActionsWarning -Message "Unable to update local assets safely! Local assets' compatibility and remote assets' compatibility are not match. $AssetsLocalOutdatedMessage"
		Return
	}
	If ($LocalAssetsTimestamp -ige $RemoteAssetsTimestamp) {
		Write-Host -Object 'Local assets is already up to date.'
		Return
	}
	Write-Host -Object 'Need to update local assets.'
	Try {
		Invoke-WebRequest -Uri $AssetsRemotePackage -OutFile $AssetsRemoteOutFileFullName @InvokeWebGetRequestParameters
	}
	Catch {
		Write-GitHubActionsWarning -Message "Unable to download remote assets package! $_ $AssetsLocalOutdatedMessage"
		Return
	}
	Try {
		New-Item -Path $AssetsRemoteExtractRoot -ItemType 'Directory' -Force -Confirm:$False |
			Out-Null
		tar --extract --file="$AssetsRemoteOutFileFullName" --directory="$AssetsRemoteExtractRoot" --gzip |
			Out-Null
		If ($LASTEXITCODE -ine 0) {
			Throw "Compression program exit code is $LASTEXITCODE."
		}
		Remove-Item -LiteralPath $AssetsRemoteOutFileFullName -Force -Confirm:$False
	}
	Catch {
		Write-GitHubActionsNotice -Message "Unable to extract remote assets package! $_ $AssetsLocalOutdatedMessage"
		Return
	}
	Try {
		Remove-Item -LiteralPath $AssetsLocalRoot -Recurse -Force -Confirm:$False
		Move-Item -LiteralPath (Join-Path -Path $AssetsRemoteExtractRoot -ChildPath 'scan-virus-ghaction-assets-main') -Destination $AssetsLocalRoot -Confirm:$False
		Remove-Item -LiteralPath $AssetsRemoteExtractRoot -Recurse -Force -Confirm:$False
	}
	Catch {
		Throw "Unable to update local assets package! $_"
	}
	Write-Host -Object 'Local assets is now up to date.'
}
Export-ModuleMember -Function @(
	'Update-GitHubActionScanVirusAssets'
)