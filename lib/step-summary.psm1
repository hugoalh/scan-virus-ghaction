#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Function Escape-MarkdownCharacter {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String]$InputObject
	)
	$InputObject -ireplace '\r?\n', '<br />' -ireplace '\\', '\\' -ireplace '\|', '\|' -ireplace '\*', '\*' -ireplace '_', '\_' -ireplace '\[', '\[' -ireplace '\]', '\]' -ireplace '^>', '\>' -ireplace '^-', '\-' |
		Write-Output
}
Function Ensure-StepSummaryFileExist {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Content
	)
	If (
		!(Test-Path -LiteralPath $Env:GITHUB_STEP_SUMMARY -PathType 'Leaf') -or
		(Get-GitHubActionsStepSummary -Sizes) -eq 0
	) {
		Set-GitHubActionsStepSummary -Value $Content
	}
}
Function Add-StepSummaryFound {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Session,
		[Parameter(Mandatory = $True, Position = 1)][String]$Indicator,
		[Parameter(Mandatory = $True, Position = 2)][Alias('Issues')][PSCustomObject[]]$Issue
	)
	Ensure-StepSummaryFileExist -Content @'
# Found
'@
	Add-GitHubActionsStepSummary -Value @"

## $(Escape-MarkdownCharacter -InputObject $Session)

|  | **Path** | **Symbol** | **Hit** |
|:-:|:--|:--|--:|
$(
	$Issue |
		ForEach-Object -Process { "| $Indicator | $(Escape-MarkdownCharacter -InputObject $_.Path) | $(Escape-MarkdownCharacter -InputObject $_.Symbol) | $($_.Hit) |" } |
		Join-String -Separator "`n"
)
"@
}
Export-ModuleMember -Function @(
	'Add-StepSummaryFound'
)
