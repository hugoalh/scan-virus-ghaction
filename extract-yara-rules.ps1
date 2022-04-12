[string]$YARARulesPath = Join-Path -Path $PSScriptRoot -ChildPath 'yara-rules'
[string]$YARARulesCompilePath = Join-Path -Path $YARARulesPath -ChildPath 'compile'
[string]$YARARulesSourcePath = Join-Path -Path $YARARulesPath -ChildPath 'source'
function Optimize-YARARules {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string]$Path
	)
	begin {}
	process {
		[string]$Content = Get-Content -Path $Path -Raw -Encoding UTF8NoBOM
		if (($Content -cmatch 'entrypoint') -and ($Content -cnotmatch '^import "pe"\n')) {
			Set-Content -Path $Path -Value "import `"pe`"`n$($Content -creplace 'entrypoint', 'pe.entry_point')" -NoNewline -Encoding UTF8NoBOM
		}
	}
	end {}
}
[string[]]$YARARulesSource = Get-ChildItem -Path $YARARulesSourcePath -Include @('*.yar', '*.yara') -Recurse -Name -File
$YARARulesSource | ForEach-Object -Process {
	[string]$YARARuleFullPathOriginal = Join-Path -Path $YARARulesSourcePath -ChildPath $_
	Optimize-YARARules -Path $YARARuleFullPathOriginal
	Invoke-Expression -Command "yarac `"$YARARuleFullPathOriginal`" `"$(Join-Path -Path $YARARulesCompilePath -ChildPath ($_.ToLower() -replace '[^a-zA-Z\d\s_-]+', '' -replace '[\s_]+', '-' -replace '\.yara?$', '.yarac'))`"" -ErrorAction Stop
}
