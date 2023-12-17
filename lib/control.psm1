#Requires -PSEdition Core -Version 7.2
[String]$CurrentWorkingDirectory = [System.Environment]::CurrentDirectory
[String]$CurrentWorkingDirectoryRegExEscape = [RegEx]::Escape($CurrentWorkingDirectory)
[Hashtable]$TsvParameters = @{
	Delimiter = "`t"
	Encoding = 'UTF8NoBOM'
}
[String[]]$Tools = ($Env:SVGHA_TOOLS ?? '') -isplit ',' |
	ForEach-Object -Process { $_.Trim() } |
	Where-Object -FilterScript { $_.Length -gt 0 }
If ($Tools.Count -eq 0) {
	Write-Error -Message 'Invalid environment variable `SVGHA_TOOLS`!' -ErrorAction 'Stop'
}
[Boolean]$ToolHasClamAV = $Tools -icontains 'clamav'
[Boolean]$ToolForceClamAV = $ToolHasClamAV -and $Tools.Count -eq 1
[Boolean]$ToolHasYara = $Tools -icontains 'yara'
[Boolean]$ToolForceYara = $ToolHasYara -and $Tools.Count -eq 1
Export-ModuleMember -Variable @(
	'CurrentWorkingDirectory',
	'CurrentWorkingDirectoryRegExEscape',
	'ToolForceClamAV',
	'ToolForceYara',
	'ToolHasClamAV',
	'ToolHasYara',
	'TsvParameters'
)
