[string[]]$YARARulesRaw = Get-ChildItem -Path "$PSScriptRoot/yara-rules" -Include @('*.yar', '*.yara') -Recurse -Force -Name
[string[]]$YARARules = $YARARulesRaw | ForEach-Object -Process {
	return "$PSScriptRoot/yara-rules/$_"
}
Invoke-Expression -Command "yarac $($YARARules -join ' ') $PSScriptRoot/yara-rules.yarac" -ErrorAction Stop
