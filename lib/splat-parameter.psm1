#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
If ($Env:GHACTION_SCANVIRUS_BUNDLE_TOOL -inotin @('all', 'clamav', 'yara')) {
	Write-GitHubActionsFail -Message 'Invalid environment variable `GHACTION_SCANVIRUS_BUNDLE_TOOL`!'
}
[Boolean]$AllBundle = $Env:GHACTION_SCANVIRUS_BUNDLE_TOOL -ieq 'all'
[Boolean]$ClamAVForce = $Env:GHACTION_SCANVIRUS_BUNDLE_TOOL -ieq 'clamav'
[Boolean]$YaraForce = $Env:GHACTION_SCANVIRUS_BUNDLE_TOOL -ieq 'yara'
[Boolean]$ClamAVBundle = $AllBundle -or $ClamAVForce
[Boolean]$YaraBundle = $AllBundle -or $YaraForce
[RegEx]$GitHubActionsWorkspaceRootRegEx = [RegEx]::Escape("$($Env:GITHUB_WORKSPACE)/")
[Hashtable]$InvokeWebRequestParameters_Get = @{
	MaximumRedirection = 1
	MaximumRetryCount = 2
	Method = 'Get'
	RetryIntervalSec = 5
}
[Hashtable]$TsvParameters = @{
	Delimiter = "`t"
	Encoding = 'UTF8NoBOM'
}
[String]$UnofficialAssetIndexFileName = 'index.tsv'
Export-ModuleMember -Variable @(
	'AllBundle',
	'ClamAVBundle',
	'ClamAVForce',
	'GitHubActionsWorkspaceRootRegEx',
	'InvokeWebRequestParameters_Get',
	'TsvParameters',
	'UnofficialAssetIndexFileName',
	'YaraBundle',
	'YaraForce'
)
