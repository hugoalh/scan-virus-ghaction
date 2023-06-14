#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'splat-parameter',
		'token'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Function Import-NetworkTarget {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Uri]$Target
	)
	Enter-GitHubActionsLogGroup -Title "Fetch file ``$Target``."
	[String]$NetworkTargetFilePath = Join-Path -Path $Env:GITHUB_WORKSPACE -ChildPath "$(New-RandomToken).tmp"
	Try {
		Invoke-WebRequest -Uri $Target -OutFile $NetworkTargetFilePath @InvokeWebRequestParameters_Get
	}
	Catch {
		Write-GitHubActionsError -Message "Unable to fetch file ``$Target``: $_"
		Return
	}
	Finally {
		Exit-GitHubActionsLogGroup
	}
	Write-Output -InputObject $NetworkTargetFilePath
}
Export-ModuleMember -Function @(
	'Import-NetworkTarget'
)
