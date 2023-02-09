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
[String]$AssetsMetadataName = 'metadata.json'
[String]$AssetsLocalRoot = Join-Path -Path $PSScriptRoot -ChildPath 'assets'
[String]$AssetsLocalMetaFullName = Join-Path -Path $AssetsLocalRoot -ChildPath $AssetsMetadataName
[String]$AssetsLocalOutdatedMessage = 'This is fine, but the local assets maybe outdated.'
[Uri]$AssetsRemoteRoot = 'https://github.com/hugoalh/scan-virus-ghaction-assets'
[Uri]$AssetsRemoteMetaUri = "$AssetsRemoteRoot/raw/main/$AssetsMetadataName"
[Uri]$AssetsRemotePackageUri = "$AssetsRemoteRoot/archive/refs/heads/main.tar.gz"
[String]$AssetsRemoteOutFileFullName = Join-Path -Path $PSScriptRoot -ChildPath 'assets-remote.tar.gz'
[String]$AssetsRemoteExtractRoot = Join-Path -Path $PSScriptRoot -ChildPath 'assets-remote'
Function Update-AssetsLocal {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param ()
	Try {
		[PSCustomObject]$LocalMetadata = Get-Content -LiteralPath $AssetsLocalMetaFullName -Raw -Encoding 'UTF8NoBOM' |
			ConvertFrom-Json -Depth 100
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
	Write-NameValue -Name 'Local Assets Compatibility' -Value $LocalMetadata.Compatibility
	Write-NameValue -Name 'Local Assets Timestamp' -Value (Get-Date -Date $LocalAssetsTimestamp @DateTimeISOParameters)
	Try {
		[PSCustomObject]$RemoteMetadata = Invoke-WebRequest -Uri $AssetsRemoteMetaUri @InvokeWebGetRequestParameters |
			Select-Object -ExpandProperty 'Content' |
			ConvertFrom-Json -Depth 100
		[DateTime]$RemoteAssetsTimestamp = Get-Date -Date $RemoteMetadata.Timestamp -AsUTC
	}
	Catch {
		Write-GitHubActionsWarning -Message "Unable to get and parse remote assets metadata! $_ $AssetsLocalOutdatedMessage"
		Write-Output -InputObject @{
			Success = $False
			Continue = $True
		}
		Return
	}
	Write-NameValue -Name 'Remote Assets Compatibility' -Value $RemoteMetadata.Compatibility
	Write-NameValue -Name 'Remote Assets Timestamp' -Value (Get-Date -Date $RemoteAssetsTimestamp @DateTimeISOParameters)
	If ($RemoteMetadata.Compatibility -ine $LocalMetadata.Compatibility) {
		Write-GitHubActionsWarning -Message "Unable to update local assets safely! Local assets' compatibility and remote assets' compatibility are not match. $AssetsLocalOutdatedMessage"
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
	Try {
		Invoke-WebRequest -Uri $AssetsRemotePackageUri -OutFile $AssetsRemoteOutFileFullName @InvokeWebGetRequestParameters
	}
	Catch {
		Write-GitHubActionsWarning -Message "Unable to download remote assets package! $_ $AssetsLocalOutdatedMessage"
		Write-Output -InputObject @{
			Success = $False
			Continue = $True
		}
		Return
	}
	Try {
		New-Item -Path $AssetsRemoteExtractRoot -ItemType 'Directory' -Force -Confirm:$False |
			Out-Null
		tar --extract --file="$AssetsRemoteOutFileFullName" --directory="$AssetsRemoteExtractRoot" --gzip |
			Out-Null
		If ($LASTEXITCODE -ine 0) {
			Throw "Exit code of the compression tool is ``$LASTEXITCODE``!"
		}
		Remove-Item -LiteralPath $AssetsRemoteOutFileFullName -Force -Confirm:$False
	}
	Catch {
		Write-GitHubActionsNotice -Message "Unable to extract remote assets package! $_ $AssetsLocalOutdatedMessage"
		Write-Output -InputObject @{
			Success = $False
			Continue = $True
		}
		Return
	}
	Try {
		Remove-Item -LiteralPath $AssetsLocalRoot -Recurse -Force -Confirm:$False
		Move-Item -LiteralPath (Join-Path -Path $AssetsRemoteExtractRoot -ChildPath 'scan-virus-ghaction-assets-main') -Destination $AssetsLocalRoot -Confirm:$False
		Remove-Item -LiteralPath $AssetsRemoteExtractRoot -Recurse -Force -Confirm:$False
	}
	Catch {
		Write-Output -InputObject @{
			Success = $False
			Continue = $False
			Reason = "Unable to update local assets package! $_"
		}
		Return
	}
	Write-Host -Object 'Local assets are now up to date.'
	Write-Output -InputObject @{
		Success = $True
		Continue = $True
	}
}
Export-ModuleMember -Function @(
	'Update-AssetsLocal'
)
