Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
[String]$MetadataName = 'metadata.json'
[String]$LocalAssetsOutdatedMessage = 'This is fine, but local assets maybe outdated.'
[String]$LocalRoot = Join-Path -Path $PSScriptRoot -ChildPath 'assets'
[String]$RemoteRoot = 'https://github.com/hugoalh/scan-virus-ghaction-assets'
[String]$RemotePackageFullName = "$RemoteRoot/archive/refs/heads/main.tar.gz"
[String]$RemotePackageExtractRoot = Join-Path -Path $PSScriptRoot -ChildPath 'assets-remote'
[String]$RemotePackageOutBranchRoot = Join-Path -Path $RemotePackageExtractRoot -ChildPath 'scan-virus-ghaction-assets-main'
[String]$RemotePackageToLocalFileFullName = Join-Path -Path $PSScriptRoot -ChildPath 'assets-remote.tar.gz'
Function Update-GitHubActionScanVirusAssets {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Try {
		[PSCustomObject]$LocalMetadata = (Get-Content -LiteralPath (Join-Path -Path $LocalRoot -ChildPath $MetadataName) -Raw -Encoding 'UTF8NoBOM' | ConvertFrom-Json -Depth 100)
	} Catch {
		Write-GitHubActionsFail -Message "Unable to get local assets' metadata in order to update local assets!"
		Return
	}
	Try {
		[PSCustomObject]$RemoteMetadata = (Invoke-WebRequest -Uri "$RemoteRoot/raw/main/$MetadataName" -UseBasicParsing -MaximumRedirection 5 -MaximumRetryCount 3 -RetryIntervalSec 5 -Method 'Get' | ConvertFrom-Json -Depth 100)
	} Catch {
		Write-GitHubActionsNotice -Message "Unable to get remote assets' metadata in order to update local assets! $LocalAssetsOutdatedMessage"
		Return
	}
	Try {
		If ($RemoteMetadata.Compatibility -ine $LocalMetadata.Compatibility) {
			Throw
		}
	} Catch {
		Write-GitHubActionsNotice -Message "Unable to safely update local assets due to local assets' compatibility and remote assets' compatibility are not match! $LocalAssetsOutdatedMessage"
		Return
	}
	Try {
		If ((Get-Date -Date $RemoteMetadata.Timestamp -AsUTC) -igt (Get-Date -Date $LocalMetadata.Timestamp -AsUTC)) {
			Try {
				Invoke-WebRequest -Uri $RemotePackageFullName -UseBasicParsing -MaximumRedirection 5 -MaximumRetryCount 3 -RetryIntervalSec 5 -Method 'Get' -OutFile $RemotePackageToLocalFileFullName
			} Catch {
				Write-GitHubActionsNotice -Message "Unable to download remote assets package! $LocalAssetsOutdatedMessage"
				Return
			}
			Try {
				New-Item -Path $RemotePackageExtractRoot -ItemType 'Directory' -Force -Confirm:$False | Out-Null
				Invoke-Expression -Command "tar --extract --file=`"$RemotePackageToLocalFileFullName`" --directory=`"$RemotePackageExtractRoot`" --gzip" | Out-Null
				Remove-Item -LiteralPath $RemotePackageToLocalFileFullName -Force -Confirm:$False
			} Catch {
				Write-GitHubActionsNotice -Message "Unable to extract remote assets package! $LocalAssetsOutdatedMessage"
				Return
			}
			Try {
				Remove-Item -LiteralPath $LocalRoot -Recurse -Force -Confirm:$False
				Move-Item -LiteralPath $RemotePackageOutBranchRoot -Destination $LocalRoot -Confirm:$False
				Remove-Item -LiteralPath $RemotePackageExtractRoot -Recurse -Force -Confirm:$False
			} Catch {
				Write-GitHubActionsFail -Message 'Unable to update local assets due to file system issues!'
				Return
			}
			Write-Host -Object 'Local assets is now up to date.'
		} Else {
			Write-Host -Object 'Local assets is already up to date.'
		}
	} Catch {
		Write-GitHubActionsNotice -Message "Unable to get local assets' timestamp and/or remote assets' timestamp! $LocalAssetsOutdatedMessage"
		Return
	}
}
Export-ModuleMember -Function @(
	'Update-GitHubActionScanVirusAssets'
)
