#Requires -PSEdition Core -Version 7.2
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name (
	@(
		'control'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
$SoftwaresVersionTable = [Ordered]@{
	'PowerShell' = $PSVersionTable.PSVersion.ToString()
	'PowerShell/Gallery:hugoalh.GitHubActionsToolkit' = Get-InstalledModule -Name 'hugoalh.GitHubActionsToolkit' -AllVersions |
		Select-Object -ExpandProperty 'Version' |
		Join-String -Separator ', '
	'Git' = git --version |
		Join-String -Separator "`n"
	'GitLFS' = git-lfs --version |
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
$SoftwaresVersionTable |
	ConvertTo-Json -Depth 100 -Compress |
	Set-Content -LiteralPath $Env:SCANVIRUS_GHACTION_SOFTWARESVERSIONFILE -Confirm:$False -Encoding 'UTF8NoBOM'
Set-Location -LiteralPath $Env:SCANVIRUS_GHACTION_ROOT
git clone --depth 1 https://github.com/hugoalh/scan-virus-ghaction-assets.git asset
Set-Location -LiteralPath $CurrentWorkingDirectory
@(
	'.git',
	'.github',
	'.gitattributes',
	'.gitignore',
	'README.md',
	'_updater.ps1',
	'_updater_gitignore.txt'
) |
	ForEach-Object -Process { Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSET_ROOT -ChildPath $_ } |
	ForEach-Object -Process { Remove-Item -LiteralPath $_ -Recurse -Force -Confirm:$False }
If (!$ToolHasClamAV) {
	Remove-Item -LiteralPath $Env:SCANVIRUS_GHACTION_ASSET_CLAMAV -Recurse -Force -Confirm:$False
}
If (!$ToolHasYara) {
	Remove-Item -LiteralPath $Env:SCANVIRUS_GHACTION_ASSET_YARA -Recurse -Force -Confirm:$False
}
Write-Host -Object 'Softwares Version: '
[PSCustomObject]$SoftwaresVersionTable |
	Format-List
