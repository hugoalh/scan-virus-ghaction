[string[]]$YARARulesRaw = Get-ChildItem -Path "$PSScriptRoot/yara-rules" -Include @('*.yar', '*.yara') -Recurse -Force -Name
Invoke-Expression -Command "yarac $($YARARulesRaw -join ' ') $PSScriptRoot/yara-rules.yarac" -ErrorAction Stop
