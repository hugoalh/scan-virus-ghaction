[string]$LocalRoot = Join-Path -Path $PSScriptRoot -ChildPath 'assets'
[string]$LocalTimestampFullName = Join-Path -Path $LocalRoot -ChildPath '_timestamp.txt'
[string]$RemoteRoot = 'https://github.com/hugoalh/scan-virus-ghaction-assets'
[string]$RemoteTimestampFullName = "$RemoteRoot/raw/main/_timestamp.txt"
[string]$RemotePackageFullName = "$RemoteRoot/archive/refs/heads/main.tar.gz"
[string]$RemotePackageFileFullName = Join-Path -Path $LocalRoot -ChildPath '_remote.tar.gz'
[string]$RemotePackageOutRoot = Join-Path -Path $LocalRoot -ChildPath '_remote'
[string]$RemotePackageOutBranchRoot = Join-Path -Path $RemotePackageOutRoot -ChildPath 'scan-virus-ghaction-assets-main'
function Update-GitHubActionScanVirusAssets {
	[CmdletBinding()][OutputType([void])]
	param()
	[datetime]$LocalTimestamp = Get-Date -Date ((Get-Content -LiteralPath $LocalTimestampFullName -Raw -Encoding 'UTF8NoBOM' -ErrorAction 'SilentlyContinue') ?? 0) -AsUTC
	[datetime]$RemoteTimestamp = Get-Date -Date (Invoke-WebRequest -Uri $RemoteTimestampFullName -UseBasicParsing -MaximumRedirection 5 -MaximumRetryCount 3 -RetryIntervalSec 5 -Method 'Get') -AsUTC
	if ($RemoteTimestamp -gt $LocalTimestamp) {
		Invoke-WebRequest -Uri $RemotePackageFullName -UseBasicParsing -MaximumRedirection 5 -MaximumRetryCount 3 -RetryIntervalSec 5 -Method 'Get' -OutFile $RemotePackageFileFullName
		Invoke-Expression -Command "tar --extract --file=`"$RemotePackageFileFullName`" --directory=`"$RemotePackageOutRoot`" --gzip"
		Remove-Item -LiteralPath $RemotePackageFileFullName -Force -Confirm:$false
		
		Copy-Item -LiteralPath $RemotePackageOutBranchRoot -Destination $LocalRoot
	}
}
Export-ModuleMember -Function 'Update-GitHubActionScanVirusAssets'
