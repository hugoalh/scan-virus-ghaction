[string]$LocalRoot = Join-Path -Path $PSScriptRoot -ChildPath 'assets'
[string]$LocalTimestampFullName = Join-Path -Path $LocalRoot -ChildPath '_timestamp.txt'
[string]$RemotePackageExtractRoot = Join-Path -Path $PSScriptRoot -ChildPath 'assets-remote'
[string]$RemotePackageOutBranchRoot = Join-Path -Path $RemotePackageExtractRoot -ChildPath 'scan-virus-ghaction-assets-main'
[string]$RemotePackageToLocalFileFullName = Join-Path -Path $PSScriptRoot -ChildPath 'assets-remote.tar.gz'
[string]$RemoteRoot = 'https://github.com/hugoalh/scan-virus-ghaction-assets'
[string]$RemotePackageFullName = "$RemoteRoot/archive/refs/heads/main.tar.gz"
[string]$RemoteTimestampFullName = "$RemoteRoot/raw/main/_timestamp.txt"
function Update-GitHubActionScanVirusAssets {
	[CmdletBinding()][OutputType([void])]
	param ()
	[datetime]$LocalTimestamp = Get-Date -Date (Get-Content -LiteralPath $LocalTimestampFullName -Raw -Encoding 'UTF8NoBOM' -ErrorAction 'SilentlyContinue') -AsUTC
	[datetime]$RemoteTimestamp = Get-Date -Date (Invoke-WebRequest -Uri $RemoteTimestampFullName -UseBasicParsing -MaximumRedirection 5 -MaximumRetryCount 3 -RetryIntervalSec 5 -Method 'Get') -AsUTC
	if ($RemoteTimestamp -gt $LocalTimestamp) {
		Invoke-WebRequest -Uri $RemotePackageFullName -UseBasicParsing -MaximumRedirection 5 -MaximumRetryCount 3 -RetryIntervalSec 5 -Method 'Get' -OutFile $RemotePackageToLocalFileFullName | Out-Null
		New-Item -Path $RemotePackageExtractRoot -ItemType 'Directory' -Force -Confirm:$false | Out-Null
		Invoke-Expression -Command "tar --extract --file=`"$RemotePackageToLocalFileFullName`" --directory=`"$RemotePackageExtractRoot`" --gzip" | Out-Null
		Remove-Item -LiteralPath $RemotePackageToLocalFileFullName -Force -Confirm:$false | Out-Null
		Remove-Item -LiteralPath $LocalRoot -Recurse -Force -Confirm:$false | Out-Null
		Move-Item -LiteralPath $RemotePackageOutBranchRoot -Destination $LocalRoot -Confirm:$false | Out-Null
		Remove-Item -LiteralPath $RemotePackageExtractRoot -Recurse -Force -Confirm:$false | Out-Null
	}
}
Export-ModuleMember -Function 'Update-GitHubActionScanVirusAssets'
