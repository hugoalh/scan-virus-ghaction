#Requires -PSEdition Core -Version 7.2
[String[]]$Tools = ($Env:SCANVIRUS_GHACTION_TOOLS ?? '') -isplit ',' |
	ForEach-Object -Process { $_.Trim() } |
	Where-Object -FilterScript { $_.Length -gt 0 }
If ($Tools.Count -eq 0) {
	Write-Error -Message 'Invalid environment variable `SCANVIRUS_GHACTION_TOOLS`!' -ErrorAction 'Stop'
}
[Boolean]$ToolForceClamAV = $Tools.Count -eq 1 -and $Tools -icontains 'clamav'
[Boolean]$ToolForceYara = $Tools.Count -eq 1 -and $Tools -icontains 'yara'
Export-ModuleMember -Variable @(
	'ToolForceClamAV',
	'ToolForceYara',
	'Tools'
)
