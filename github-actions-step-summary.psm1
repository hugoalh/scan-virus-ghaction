Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
[string]$StepSummaryTemplateFullName = Join-Path -Path $PSScriptRoot -ChildPath 'github-actions-step-summary-template.md'
function Initialize-StepSummary {
	[CmdletBinding()][OutputType([void])]
	param ()
	Get-Content -LiteralPath $StepSummaryTemplateFullName -Raw -Encoding 'UTF8NoBOM' | Set-GitHubActionsStepSummary
	Write-StepSummaryPlaceholder -Placeholder ([regex]::Escape('<!-- metadata.job.id -->')) -Value $env:GITHUB_JOB
	Write-StepSummaryPlaceholder -Placeholder ([regex]::Escape('<!-- metadata.run.id -->')) -Value $env:GITHUB_RUN_ID
	Write-StepSummaryPlaceholder -Placeholder ([regex]::Escape('<!-- metadata.run.number -->')) -Value $env:GITHUB_RUN_NUMBER
	Write-StepSummaryPlaceholder -Placeholder ([regex]::Escape('<!-- metadata.run.attempt -->')) -Value $env:GITHUB_RUN_ATTEMPT
}
function Remove-StepSummary {
	[CmdletBinding()][OutputType([void])]
	param ()
	return Remove-GitHubActionsStepSummary
}
function Write-StepSummaryAnnotationWarning {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][Alias('Content')][string]$Message
	)
	return Write-StepSummaryPlaceholder -Placeholder ([regex]::Escape('<!-- warnings.item -->')) -Value "- $Message" -Append
}
function Write-StepSummaryPlaceholder {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][Alias('Key', 'Name')][string]$Placeholder,
		[Parameter(Mandatory = $true, Position = 1)][string]$Value,
		[switch]$Append
	)
	[string]$Content = Get-GitHubActionsStepSummary -Raw
	$Content -replace $Placeholder, "$Value$($Append ? "`n$Placeholder" : '')"
	Set-GitHubActionsStepSummary -Value $Content
}
Export-ModuleMember -Function 'Initialize-StepSummary'
