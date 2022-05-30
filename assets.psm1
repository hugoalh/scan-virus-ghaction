Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
[string]$CompatibilityName = '_compatibility.txt'
[string]$TimestampName = '_timestamp.txt'
[string]$LocalAssetsOutdatedMessage = 'This is fine, but local assets maybe outdated.'
[string]$LocalRoot = Join-Path -Path $PSScriptRoot -ChildPath 'assets'
[string]$LocalCompatibilityFullName = Join-Path -Path $LocalRoot -ChildPath $CompatibilityName
[string]$LocalTimestampFullName = Join-Path -Path $LocalRoot -ChildPath $TimestampName
[string]$RemoteRoot = 'https://github.com/hugoalh/scan-virus-ghaction-assets'
[string]$RemotePackageExtractRoot = Join-Path -Path $PSScriptRoot -ChildPath 'assets-remote'
[string]$RemotePackageOutBranchRoot = Join-Path -Path $RemotePackageExtractRoot -ChildPath 'scan-virus-ghaction-assets-main'
[string]$RemotePackageToLocalFileFullName = Join-Path -Path $PSScriptRoot -ChildPath 'assets-remote.tar.gz'
[string]$RemotePackageFullName = "$RemoteRoot/archive/refs/heads/main.tar.gz"
[string]$RemoteCompatibilityFullName = "$RemoteRoot/raw/main/$CompatibilityName"
[string]$RemoteTimestampFullName = "$RemoteRoot/raw/main/$TimestampName"
function Update-GitHubActionScanVirusAssets {
	[CmdletBinding()][OutputType([void])]
	param ()
	try {
		[uint]$LocalCompatibility = [uint]::Parse((Get-Content -LiteralPath $LocalCompatibilityFullName -Raw -Encoding 'UTF8NoBOM'))
	} catch {
		Write-GitHubActionsNotice -Message "Unable to get local assets' compatibility in order to update local assets! $LocalAssetsOutdatedMessage"
		return
	}
	try {
		[uint]$RemoteCompatibility = [uint]::Parse((Invoke-WebRequest -Uri $RemoteCompatibilityFullName -UseBasicParsing -MaximumRedirection 5 -MaximumRetryCount 3 -RetryIntervalSec 5 -Method 'Get'))
	} catch {
		Write-GitHubActionsNotice -Message "Unable to get remote assets' compatibility in order to update local assets! $LocalAssetsOutdatedMessage"
		return
	}
	if ($RemoteCompatibility -ne $LocalCompatibility) {
		Write-GitHubActionsNotice -Message "Unable to update local assets without issues due to local assets' compatibility and remote assets' compatibility are not match! $LocalAssetsOutdatedMessage"
		return
	}
	try {
		[datetime]$LocalTimestamp = Get-Date -Date (Get-Content -LiteralPath $LocalTimestampFullName -Raw -Encoding 'UTF8NoBOM') -AsUTC
	} catch {
		Write-GitHubActionsNotice -Message "Unable to get local assets' timestamp in order to update local assets! $LocalAssetsOutdatedMessage"
		return
	}
	try {
		[datetime]$RemoteTimestamp = Get-Date -Date (Invoke-WebRequest -Uri $RemoteTimestampFullName -UseBasicParsing -MaximumRedirection 5 -MaximumRetryCount 3 -RetryIntervalSec 5 -Method 'Get') -AsUTC
	} catch {
		Write-GitHubActionsNotice -Message "Unable to get remote assets' timestamp in order to update local assets! $LocalAssetsOutdatedMessage"
		return
	}
	if ($RemoteTimestamp -gt $LocalTimestamp) {
		try {
			Invoke-WebRequest -Uri $RemotePackageFullName -UseBasicParsing -MaximumRedirection 5 -MaximumRetryCount 3 -RetryIntervalSec 5 -Method 'Get' -OutFile $RemotePackageToLocalFileFullName
		} catch {
			Write-GitHubActionsNotice -Message "Unable to download remote assets package! $LocalAssetsOutdatedMessage"
			return
		}
		try {
			New-Item -Path $RemotePackageExtractRoot -ItemType 'Directory' -Force -Confirm:$false | Out-Null
			Invoke-Expression -Command "tar --extract --file=`"$RemotePackageToLocalFileFullName`" --directory=`"$RemotePackageExtractRoot`" --gzip" | Out-Null
			Remove-Item -LiteralPath $RemotePackageToLocalFileFullName -Force -Confirm:$false | Out-Null
		} catch {
			Write-GitHubActionsNotice -Message "Unable to extract remote assets package! $LocalAssetsOutdatedMessage"
			return
		}
		try {
			Remove-Item -LiteralPath $LocalRoot -Recurse -Force -Confirm:$false | Out-Null
			Move-Item -LiteralPath $RemotePackageOutBranchRoot -Destination $LocalRoot -Confirm:$false | Out-Null
			Remove-Item -LiteralPath $RemotePackageExtractRoot -Recurse -Force -Confirm:$false | Out-Null
		} catch {
			Write-GitHubActionsFail -Message 'Unable to update local assets due to I/O issues!'
		}
	}
	return
}
Export-ModuleMember -Function 'Update-GitHubActionScanVirusAssets'
