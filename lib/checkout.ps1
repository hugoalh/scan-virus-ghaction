#Requires -PSEdition Core -Version 7.2
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name @(
	(Join-Path -Path $PSScriptRoot -ChildPath 'control.psm1')
) -Scope 'Local'
$SoftwaresVersionTable = [Ordered]@{
	'PowerShell' = $PSVersionTable.PSVersion.ToString()
	"powershell/gallery:hugoalh.GitHubActionsToolkit" = Get-InstalledModule -Name 'hugoalh.GitHubActionsToolkit' -AllVersions |
		Select-Object -ExpandProperty 'Version' |
		Join-String -Separator ', '
	'Git' = git --no-pager --version |
		Join-String -Separator "`n"
	'Git LFS' = git-lfs --version |
		Join-String -Separator "`n"
}
If ($ToolHasClamAV) {
	$SoftwaresVersionTable.('ClamAV Daemon') = clamd --version |
		Join-String -Separator "`n"
	$SoftwaresVersionTable.('ClamAV Scan Daemon') = clamdscan --version |
		Join-String -Separator "`n"
	$SoftwaresVersionTable.('ClamAV Scan') = clamscan --version |
		Join-String -Separator "`n"
	$SoftwaresVersionTable.('FreshClam') = freshclam --version |
		Join-String -Separator "`n"
}
If ($ToolHasYara) {
	$SoftwaresVersionTable.('YARA') = yara --version |
		Join-String -Separator "`n"
}
Set-Location -LiteralPath $Env:SCANVIRUS_GHACTION_ROOT
git --no-pager clone --depth 1 https://github.com/hugoalh/scan-virus-ghaction-assets.git assets
Set-Location -LiteralPath $Env:SCANVIRUS_GHACTION_ASSETS_ROOT
$Null = git --no-pager config --global --add safe.directory $Env:SCANVIRUS_GHACTION_ASSETS_ROOT
$SoftwaresVersionTable.('git/github:hugoalh/scan-virus-ghaction-assets') = git --no-pager log --format=%H --no-color |
	Join-String -Separator "`n"
Set-Location -LiteralPath $CurrentWorkingDirectory
@(
	'.git',
	'.github',
	'.gitattributes',
	'.gitignore',
	'README.md',
	'updater.ps1'
) |
	ForEach-Object -Process { Remove-Item -LiteralPath (Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSETS_ROOT -ChildPath $_) -Recurse -Force -Confirm:$False }
If (!$ToolHasClamAV) {
	Remove-Item -LiteralPath $Env:SCANVIRUS_GHACTION_ASSETS_CLAMAV -Recurse -Force -Confirm:$False
}
If (!$ToolHasYara) {
	Remove-Item -LiteralPath $Env:SCANVIRUS_GHACTION_ASSETS_YARA -Recurse -Force -Confirm:$False
}
$SoftwaresVersionTable |
	ConvertTo-Json -Depth 100 -Compress |
	Set-Content -LiteralPath $Env:SCANVIRUS_GHACTION_SOFTWARESVERSIONFILE -Confirm:$False -Encoding 'UTF8NoBOM'
Write-Host -Object 'Softwares Version: '
[PSCustomObject]$SoftwaresVersionTable |
	Format-List |
	Out-String -Width 120
