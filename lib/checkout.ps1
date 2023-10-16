#Requires -PSEdition Core -Version 7.2
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name (
	@(
		'splat-parameter'
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
If ($Tools -icontains 'clamav') {
	$SoftwaresVersionTable.('ClamAV Daemon') = clamd --version |
		Join-String -Separator "`n"
	$SoftwaresVersionTable.('ClamAV Scan Daemon') = clamdscan --version |
		Join-String -Separator "`n"
	$SoftwaresVersionTable.('ClamAV Scan') = clamscan --version |
		Join-String -Separator "`n"
	$SoftwaresVersionTable.('FreshClam') = freshclam --version |
		Join-String -Separator "`n"
}
If ($Tools -icontains 'yara') {
	$SoftwaresVersionTable.('YARA') = yara --version |
		Join-String -Separator "`n"
}
$SoftwaresVersionTable |
	ConvertTo-Json -Depth 100 -Compress |
	Set-Content -LiteralPath $Env:SCANVIRUS_GHACTION_SOFTWARESVERSIONFILE -Confirm:$False -Encoding 'UTF8NoBOM'
$CurrentWorkingDirectory = Get-Location
Set-Location -LiteralPath $Env:SCANVIRUS_GHACTION_ROOT
git clone --depth 1 https://github.com/hugoalh/scan-virus-ghaction-assets.git asset
Set-Location -LiteralPath $CurrentWorkingDirectory
Remove-Item -LiteralPath (Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSET_ROOT -ChildPath '.git') -Recurse -Force -Confirm:$False
Remove-Item -LiteralPath (Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSET_ROOT -ChildPath '.github') -Recurse -Force -Confirm:$False
Remove-Item -LiteralPath (Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSET_ROOT -ChildPath '.gitattributes') -Recurse -Force -Confirm:$False
Remove-Item -LiteralPath (Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSET_ROOT -ChildPath '.gitignore') -Recurse -Force -Confirm:$False
Remove-Item -LiteralPath (Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSET_ROOT -ChildPath 'README.md') -Recurse -Force -Confirm:$False
Remove-Item -LiteralPath (Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSET_ROOT -ChildPath '_updater.ps1') -Recurse -Force -Confirm:$False
Remove-Item -LiteralPath (Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSET_ROOT -ChildPath '_updater_gitignore.txt') -Recurse -Force -Confirm:$False
If ($Tools -inotcontains 'clamav') {
	Remove-Item -LiteralPath $Env:SCANVIRUS_GHACTION_ASSET_CLAMAV -Recurse -Force -Confirm:$False
}
If ($Tools -inotcontains 'yara') {
	Remove-Item -LiteralPath $Env:SCANVIRUS_GHACTION_ASSET_YARA -Recurse -Force -Confirm:$False
}
Write-Host -Object 'Softwares Version: '
[PSCustomObject]$SoftwaresVersionTable |
	Format-List
