[string[]]$YARAFileExtensions = @('*.yar', '*.yara')
[hashtable]$YARARules = @{
	common = @()
}
[string]$YARARulesSourcePath = "$PSScriptRoot/yara-rules/source"
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
[string[]]$YARARulesCommonRaw = Get-ChildItem -Path $YARARulesSourcePath -Include $YARAFileExtensions -Name -File
[string[]]$YARARulesGroup = Get-ChildItem -Path $YARARulesSourcePath -Name -Directory
$YARARulesCommonRaw | ForEach-Object -Process {
	[string]$YARARuleCommonPath = "$YARARulesSourcePath/$_"
	Optimize-YARARules -Path $YARARuleCommonPath
	$YARARules.common += $YARARuleCommonPath
}
$YARARulesGroup | ForEach-Object -Process {
	[string]$YARARulesGroupName = ($_ -replace '[^a-zA-Z\d _-]', '' -replace '[ _]', '-').ToLower()
	[string]$YARARulesGroupPath = "$YARARulesSourcePath/$_"
	$YARARules[$YARARulesGroupName] = @()
	[string[]]$YARARulesGroupRaw = Get-ChildItem -Path $YARARulesGroupPath -Include $YARAFileExtensions -Recurse -Name -File
	$YARARulesGroupRaw | ForEach-Object -Process {
		[string]$YARARuleGroupPath = "$YARARulesGroupPath/$_"
		Optimize-YARARules -Path $YARARuleGroupPath
		$YARARules[$YARARulesGroupName] += $YARARuleGroupPath
	}
}
$YARARules.Keys | ForEach-Object -Process {
	Invoke-Expression -Command "yarac $($YARARules[$_] -join ' ') $PSScriptRoot/yara-rules/compile/$_.yarac" -ErrorAction Stop
}
