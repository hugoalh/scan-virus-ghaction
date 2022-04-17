[hashtable[]]$YARARulesSourceRepositories = @(
	@{
		Name = 'blacktop'
		URL = 'https://github.com/blacktop/docker-yara.git'
		Branch = 'master'
		Index = 'w-rules/rules/index.yar'
	}
	@{
		Name = 'yara-community'
		URL = 'https://github.com/Yara-Rules/rules.git'
		Branch = 'master'
		Index = 'index.yar'
	}
)

[string]$OriginalPreference_ErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'Stop'
[string]$YARARulesSourcePath = Join-Path -Path '/tmp' -ChildPath (New-Guid).Guid
[string]$YARARulesCompilePath = Join-Path -Path $PSScriptRoot -ChildPath 'yara-rules' -AdditionalChildPath 'compile'
$YARARulesSourceRepositories | ForEach-Object -Process {
	[string]$YARARuleSourceRepositoryLocal = Join-Path -Path $YARARulesSourcePath -ChildPath $_.Name
	Invoke-Expression -Command "git clone --branch `"$($_.Branch)`" --recurse-submodules --verbose `"$($_.URL)`" `"$YARARuleSourceRepositoryLocal`""
	Invoke-Expression -Command "yarac `"$(Join-Path -Path $YARARuleSourceRepositoryLocal -ChildPath $_.Index)`" `"$(Join-Path -Path $YARARulesCompilePath -ChildPath "$($_.Name).yarac")`""
}
$ErrorActionPreference = $OriginalPreference_ErrorAction
