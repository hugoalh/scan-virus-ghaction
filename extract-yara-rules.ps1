Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local' -ErrorAction Stop
[string]$YARARulesPath = Join-Path -Path $PSScriptRoot -ChildPath 'yara-rules'
[string]$YARARulesCompilePath = Join-Path -Path $YARARulesPath -ChildPath 'compile'
[string]$YARARulesSourcePath = Join-Path -Path $YARARulesPath -ChildPath 'source'
[string[]]$YARARulesSource = Get-ChildItem -Path $YARARulesSourcePath -Include @('*.yar', '*.yara') -Recurse -Name -File
$YARARulesSource | ForEach-Object -Process {
	Invoke-Expression -Command "yarac --no-warnings `"$(Join-Path -Path $YARARulesSourcePath -ChildPath $_)`" `"$(Join-Path -Path $YARARulesCompilePath -ChildPath ($_.ToLower() -replace '[^a-zA-Z\d\s_-]+', '' -replace '[\s_]+', '-' -replace '\.yara?$', '.yarac'))`"" -ErrorAction Stop
}
Enter-GHActionsLogGroup -Title 'YARA Rules:'
Get-ChildItem -Path $YARARulesPath -Include '*.yarac' -Name -File
Exit-GHActionsLogGroup