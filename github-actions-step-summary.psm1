Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
[string]$TemplateFullName = Join-Path -Path $PSScriptRoot -ChildPath 'github-actions-step-summary-template.md'
[string]$PlaceholderEnd = ' -->'
[string]$PlaceholderStart = '<!-- '
[string]$PlaceholderEndRegularExpression = [regex]::Escape($PlaceholderEnd)
[string]$PlaceholderStartRegularExpression = [regex]::Escape($PlaceholderStart)
[string]$MetadataStatusEnd = "$($PlaceholderStart)metadata.status.end$PlaceholderEnd"
[string]$MetadataStatusStart = "$($PlaceholderStart)metadata.status.start$PlaceholderEnd"
[string]$MetadataStatusRegularExpression = "$([regex]::Escape($MetadataStatusEnd))``.+?``$([regex]::Escape($MetadataStatusStart))"
[string]$TruncateMessage = "`n`n*... (Truncated)*"
function Initialize-StepSummary {
	[CmdletBinding()][OutputType([void])]
	param ()
	Get-Content -LiteralPath $TemplateFullName -Raw -Encoding 'UTF8NoBOM' | Set-GitHubActionsStepSummary
	Write-StepSummaryMonoPlaceholder -Placeholder 'metadata.job.id' -Value $env:GITHUB_JOB
	Write-StepSummaryMonoPlaceholder -Placeholder 'metadata.run.id' -Value $env:GITHUB_RUN_ID
	Write-StepSummaryMonoPlaceholder -Placeholder 'metadata.run.number' -Value $env:GITHUB_RUN_NUMBER
	Write-StepSummaryMonoPlaceholder -Placeholder 'metadata.run.attempt' -Value $env:GITHUB_RUN_ATTEMPT
}
function Optimize-StepSummary {
	[CmdletBinding()][OutputType([void])]
	param ()
	Set-GitHubActionsStepSummary -Value ((Get-GitHubActionsStepSummary -Raw) -replace "$([regex]::Escape('<!-- ')).+?$([regex]::Escape(' -->'))", '').TrimEnd()
	if ((Get-GitHubActionsStepSummary -Size) -gt 1MB) {
		Set-GitHubActionsStepSummary -Value "$((Get-GitHubActionsStepSummary -Raw)[0..(1MB - $TruncateMessage.Length - 1)] -join '')$TruncateMessage"
	}
	return
}
function Remove-StepSummary {
	[CmdletBinding()][OutputType([void])]
	param ()
	return Remove-GitHubActionsStepSummary
}
function Set-StepSummaryAppendPlaceholder {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][Alias('Key', 'Name')][string]$Placeholder,
		[Parameter(Mandatory = $true, Position = 1)][Alias('Content', 'Message')][string]$Value
	)
	return Set-GitHubActionsStepSummary -Value ((Get-GitHubActionsStepSummary -Raw) -replace "$PlaceholderStartRegularExpression$([regex]::Escape($Placeholder))$PlaceholderEndRegularExpression", "$Value`n$PlaceholderStart$Placeholder$PlaceholderEnd")
}
function Set-StepSummaryMonoPlaceholder {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][Alias('Key', 'Name')][string]$Placeholder,
		[Parameter(Mandatory = $true, Position = 1)][Alias('Content', 'Message')][string]$Value
	)
	return Set-GitHubActionsStepSummary -Value ((Get-GitHubActionsStepSummary -Raw) -replace "$PlaceholderStartRegularExpression$([regex]::Escape($Placeholder))$PlaceholderEndRegularExpression", $Value)
}
function Set-StepSummaryStatus {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][Alias('Content')][string]$Message
	)
	return Set-GitHubActionsStepSummary -Value ((Get-GitHubActionsStepSummary -Raw) -replace $MetadataStatusRegularExpression, "$MetadataStatusStart``$Message``$MetadataStatusEnd")
}
Export-ModuleMember -Function @(
	'Initialize-StepSummary',
	'Optimize-StepSummary',
	'Remove-StepSummary',
	'Set-StepSummaryAppendPlaceholder'
	'Set-StepSummaryMonoPlaceholder',
	'Set-StepSummaryStatus'
)
