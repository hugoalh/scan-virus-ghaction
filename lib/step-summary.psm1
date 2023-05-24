#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Function Escape-MarkdownCharacter {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String]$InputObject
	)
	$InputObject -ireplace '\\', '\\'  -ireplace '\r?\n', '<br />'-ireplace '\|', '\|' -ireplace '\*', '\*' -ireplace '_', '\_' -ireplace '\[', '\[' -ireplace '\]', '\]' -ireplace '^>', '\>' -ireplace '^-', '\-' |
		Write-Output
}
Function Ensure-StepSummaryFileExist {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Position = 0)][String]$Content = ''
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
Function Add-StepSummaryStatistics {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][PSCustomObject[]]$TotalElements,
		[Parameter(Mandatory = $True, Position = 1)][PSCustomObject[]]$TotalSizes,
		[Parameter(Mandatory = $True, Position = 2)][AllowEmptyCollection()][String[]]$IssuesOperations,
		[Parameter(Mandatory = $True, Position = 3)][AllowEmptyCollection()][String[]]$IssuesSessions
	)
	Ensure-StepSummaryFileExist
	[String[]]$Result = @(@"

# Statistics

## Elements

| **Type** | **Sum** | **Minimum** | **Average** | **Maximum** | **StandardDeviation** | **%** |
|:-:|--:|--:|--:|--:|--:|--:|
$(
	$TotalElements |
		ForEach-Object -Process { "| $($_.Type) | $($_.Sum ?? '') | $($_.Minimum ?? '') | $($_.Average ?? '') | $($_.Maximum ?? '') | $($_.StandardDeviation ?? '') | $($_.Percentage ?? '') |" } |
		Join-String -Separator "`n"
)

## Sizes

| **Type** | **Sum** | **Minimum** | **Average** | **Maximum** | **StandardDeviation** | **%** |
|:-:|--:|--:|--:|--:|--:|--:|
$(
	$TotalSizes |
		ForEach-Object -Process { "| $($_.Type) | $($_.Sum ?? '') | $($_.Minimum ?? '') | $($_.Average ?? '') | $($_.Maximum ?? '') | $($_.StandardDeviation ?? '') | $($_.Percentage ?? '') |" } |
	Join-String -Separator "`n"
)
"@)
	If ($IssuesOperations.Count -gt 0) {
		$Result += @"

## Issues Operations

$(
	$IssuesOperations |
		ForEach-Object -Process { Escape-MarkdownCharacter -InputObject $_ } |
		Join-String -Separator "`n" -FormatString '- {0}'
)
"@
	}
	If ($IssuesSessions.Count -gt 0) {
		$Result += @"

## Issues Sessions

$(
	$IssuesSessions |
		ForEach-Object -Process { Escape-MarkdownCharacter -InputObject $_ } |
		Join-String -Separator "`n" -FormatString '- {0}'
)
"@
	}
	Add-GitHubActionsStepSummary -Value (
		$Result |
			Join-String -Separator "`n"
	)
}
Export-ModuleMember -Function @(
	'Add-StepSummaryFound',
	'Add-StepSummaryStatistics'
)
