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
	'GitHubActionsWorkspaceRootRegEx',
	'InvokeWebRequestParameters_Get',
	'TsvParameters',
	'UnofficialAssetIndexFileName'
)
