Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
[Hashtable]$AssetsConstant = @{
	Local = @{
		Root = Join-Path -Path $PSScriptRoot -ChildPath 'assets'
		OutdatedMessage = 'This is fine, but local assets maybe outdated.'
	}
	Remote = @{
		Root = 'https://github.com/hugoalh/scan-virus-ghaction-assets'
		OutFileFullName = Join-Path -Path $PSScriptRoot -ChildPath 'assets-remote.tar.gz'
		ExtractRoot = Join-Path -Path $PSScriptRoot -ChildPath 'assets-remote'
	}
	MetadataName = 'metadata.json'
}
$AssetsConstant.Remote.Package = "$($AssetsConstant.Remote.Root)/archive/refs/heads/main.tar.gz"
Function Update-GitHubActionScanVirusAssets {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Try {
		[PSCustomObject]$LocalMetadata = (Get-Content -LiteralPath (Join-Path -Path $AssetsConstant.Local.Root -ChildPath $AssetsConstant.MetadataName) -Raw -Encoding 'UTF8NoBOM' | ConvertFrom-Json -Depth 100)
		[DateTime]$LocalAssetsTimestamp = Get-Date -Date $LocalMetadata.Timestamp -AsUTC
	} Catch {
		Write-GitHubActionsFail -Message "Unable to get local assets' metadata in order to update local assets! Local assets maybe modified unexpectedly."
		Throw
	}
	Try {
		[PSCustomObject]$RemoteMetadata = (Invoke-WebRequest -Uri "$($AssetsConstant.Remote.Root)/raw/main/$($AssetsConstant.MetadataName)" -UseBasicParsing -MaximumRedirection 5 -MaximumRetryCount 5 -RetryIntervalSec 5 -Method 'Get' | ConvertFrom-Json -Depth 100)
		[DateTime]$RemoteAssetsTimestamp = Get-Date -Date $RemoteMetadata.Timestamp -AsUTC
	} Catch {
		Write-GitHubActionsNotice -Message "Unable to get remote assets' metadata in order to update local assets! $($AssetsConstant.Local.OutdatedMessage)"
		Return
	}
	If ($RemoteMetadata.Compatibility -ine $LocalMetadata.Compatibility) {
		Write-GitHubActionsNotice -Message "Unable to safely update local assets due to local assets' compatibility and remote assets' compatibility are not match! $($AssetsConstant.Local.OutdatedMessage)"
		Return
	}
	If ($RemoteAssetsTimestamp -igt $LocalAssetsTimestamp) {
		Try {
			Invoke-WebRequest -Uri $AssetsConstant.Remote.Package -UseBasicParsing -MaximumRedirection 5 -MaximumRetryCount 5 -RetryIntervalSec 5 -Method 'Get' -OutFile $AssetsConstant.Remote.OutFileFullName
		} Catch {
			Write-GitHubActionsNotice -Message "Unable to download remote assets package! $($AssetsConstant.Local.OutdatedMessage)"
			Return
		}
		Try {
			New-Item -Path $AssetsConstant.Remote.ExtractRoot -ItemType 'Directory' -Force -Confirm:$False | Out-Null
			Invoke-Expression -Command "tar --extract --file=`"$($AssetsConstant.Remote.OutFileFullName)`" --directory=`"$($AssetsConstant.Remote.ExtractRoot)`" --gzip" | Out-Null
			If ($LASTEXITCODE -ine 0) {
				Throw
			}
			Remove-Item -LiteralPath $AssetsConstant.Remote.OutFileFullName -Force -Confirm:$False
		} Catch {
			Write-GitHubActionsNotice -Message "Unable to extract remote assets package! $($AssetsConstant.Local.OutdatedMessage)"
			Return
		}
		Try {
			Remove-Item -LiteralPath $AssetsConstant.Local.Root -Recurse -Force -Confirm:$False
			Move-Item -LiteralPath (Join-Path -Path $AssetsConstant.Remote.ExtractRoot -ChildPath 'scan-virus-ghaction-assets-main') -Destination $AssetsConstant.Local.Root -Confirm:$False
			Remove-Item -LiteralPath $AssetsConstant.Remote.ExtractRoot -Recurse -Force -Confirm:$False
		} Catch {
			Write-GitHubActionsFail -Message "Unable to update local assets due to file system issues: $_"
			Throw
		}
		Write-Host -Object 'Local assets is now up to date.'
		Return
	}
	Write-Host -Object 'Local assets is already up to date.'
}
Export-ModuleMember -Function @(
	'Update-GitHubActionScanVirusAssets'
)
