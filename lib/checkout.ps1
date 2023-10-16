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
Write-Host -Object 'Softwares Version: '
[PSCustomObject]$SoftwaresVersionTable |
	Format-List
