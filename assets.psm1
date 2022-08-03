Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
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
		[PSCustomObject]$LocalMetadata = (Get-Content -LiteralPath (Join-Path -Path $AssetsLocalRoot -ChildPath $AssetsMetadataName) -Raw -Encoding 'UTF8NoBOM' | ConvertFrom-Json -Depth 100)
		[DateTime]$LocalAssetsTimestamp = Get-Date -Date $LocalMetadata.Timestamp -AsUTC
	} Catch {
		Throw "Unable to get local assets' metadata in order to update local assets! Local assets maybe modified unexpectedly."
	}
	Try {
		[PSCustomObject]$RemoteMetadata = (Invoke-WebRequest -Uri "$AssetsRemoteRoot/raw/main/$AssetsMetadataName" -UseBasicParsing -MaximumRedirection 5 -MaximumRetryCount 5 -RetryIntervalSec 5 -Method 'Get' | ConvertFrom-Json -Depth 100)
		[DateTime]$RemoteAssetsTimestamp = Get-Date -Date $RemoteMetadata.Timestamp -AsUTC
	} Catch {
		Write-GitHubActionsNotice -Message "Unable to get remote assets' metadata in order to update local assets! $AssetsLocalOutdatedMessage"
		Return
	}
	If ($RemoteMetadata.Compatibility -ine $LocalMetadata.Compatibility) {
		Write-GitHubActionsNotice -Message "Unable to safely update local assets due to local assets' compatibility and remote assets' compatibility are not match! $($AssetsLocalOutdatedMessage)"
		Return
	}
	If ($RemoteAssetsTimestamp -igt $LocalAssetsTimestamp) {
		Try {
			Invoke-WebRequest -Uri $AssetsRemotePackage -UseBasicParsing -MaximumRedirection 5 -MaximumRetryCount 5 -RetryIntervalSec 5 -Method 'Get' -OutFile $AssetsRemoteOutFileFullName
		} Catch {
			Write-GitHubActionsNotice -Message "Unable to download remote assets package! $AssetsLocalOutdatedMessage"
			Return
		}
		Try {
			New-Item -Path $AssetsRemoteExtractRoot -ItemType 'Directory' -Force -Confirm:$False | Out-Null
			Invoke-Expression -Command "tar --extract --file=`"$AssetsRemoteOutFileFullName`" --directory=`"$AssetsRemoteExtractRoot`" --gzip" | Out-Null
			If ($LASTEXITCODE -ine 0) {
				Throw
			}
			Remove-Item -LiteralPath $AssetsRemoteOutFileFullName -Force -Confirm:$False
		} Catch {
			Write-GitHubActionsNotice -Message "Unable to extract remote assets package! $AssetsLocalOutdatedMessage"
			Return
		}
		Try {
			Remove-Item -LiteralPath $AssetsLocalRoot -Recurse -Force -Confirm:$False
			Move-Item -LiteralPath (Join-Path -Path $AssetsRemoteExtractRoot -ChildPath 'scan-virus-ghaction-assets-main') -Destination $AssetsLocalRoot -Confirm:$False
			Remove-Item -LiteralPath $AssetsRemoteExtractRoot -Recurse -Force -Confirm:$False
		} Catch {
			Throw "Unable to update local assets due to file system issues: $_"
		}
		Write-Host -Object 'Local assets is now up to date.'
		Return
	}
	Write-Host -Object 'Local assets is already up to date.'
}
Export-ModuleMember -Function @(
	'Update-GitHubActionScanVirusAssets'
)
