#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Function Escape-MarkdownCharacter {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String]$InputObject
	)
	$InputObject-ireplace '\\', '\\'  -ireplace '\r?\n', '<br />' -ireplace '\|', '\|' -ireplace '\*', '\*' -ireplace '_', '\_' -ireplace '\[', '\[' -ireplace '\]', '\]' -ireplace '>', '\>' -ireplace '^-', '\-' |
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
		[Parameter(Mandatory = $True, Position = 1)][Alias('Issues')][PSCustomObject[]]$Issue
	)
	Ensure-StepSummaryFileExist -Content @'
# Found
'@
	Add-GitHubActionsSummary -Value @"

## $(Escape-MarkdownCharacter -InputObject $Session)

|  | **Path** | **Symbol** | **Hit** |
|:-:|:--|:--|--:|
$(
	$Issue |
		ForEach-Object -Process { "| $($_.Indicator) | $(Escape-MarkdownCharacter -InputObject $_.Path) | $(Escape-MarkdownCharacter -InputObject $_.Symbol) | $($_.Hit) |" } |
		Join-String -Separator "`n"
)
"@
}
Function Add-StepSummaryStatistics {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][PSCustomObject[]]$StatisticsTable,
		[Parameter(Mandatory = $True, Position = 1)][AllowEmptyCollection()][String[]]$Issues,
		[Parameter(Mandatory = $True, Position = 2)][AllowEmptyCollection()][String[]]$SessionsFound
	)
	Ensure-StepSummaryFileExist
	[String[]]$Result = @(@"

# Statistics

| **Type** | **Element** | **Size B** | **Size KB** | **Size MB** | **Size GB** | **Size TB** |
|:-:|--:|--:|--:|--:|--:|--:|
$(
	$StatisticsTable |
		ForEach-Object -Process { "| $($_.Type) | $($_.Element) | $($_.SizeB) | $($_.SizeKb) | $($_.SizeMb) | $($_.SizeGb) | $($_.SizeTb) |" } |
		Join-String -Separator "`n"
)
"@)
	If ($Issues.Count -gt 0) {
		$Result += @"

## Issues

$(
	$Issues |
		ForEach-Object -Process { Escape-MarkdownCharacter -InputObject $_ } |
		Join-String -Separator "`n" -FormatString '- {0}'
)
"@
	}
	If ($SessionsFound.Count -gt 0) {
		$Result += @"

## Sessions Found

$(
	$SessionsFound |
		ForEach-Object -Process { Escape-MarkdownCharacter -InputObject $_ } |
		Join-String -Separator "`n" -FormatString '- {0}'
)
"@
	}
	Add-GitHubActionsSummary -Value (
		$Result |
			Join-String -Separator "`n"
	)
}
Export-ModuleMember -Function @(
	'Add-StepSummaryFound',
	'Add-StepSummaryStatistics'
)
