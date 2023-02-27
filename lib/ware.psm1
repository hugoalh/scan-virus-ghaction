#Requires -PSEdition Core
#Requires -Version 7.3
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'display'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Function Get-HardwareMeta {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Enter-GitHubActionsLogGroup -Title 'Hardware Information: '
	hwinfo --all
	Exit-GitHubActionsLogGroup
}
Function Get-SoftwareMeta {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Enter-GitHubActionsLogGroup -Title 'Environment Variables: '
	Get-ChildItem -LiteralPath 'Env:\' |
		ForEach-Object -Process {
			If ($_.Name -ieq 'ACTIONS_RUNTIME_TOKEN') {
				[PSCustomObject]@{
					Name = $_.Name
					Value = '***'
				}
			}
			Else {
				[PSCustomObject]@{
					Name = $_.Name
					Value = $_.Value
				}
			}
		}
		Format-Table -AutoSize -Wrap
	Exit-GitHubActionsLogGroup
	Enter-GitHubActionsLogGroup -Title 'PowerShell (`pwsh`): '
	Write-NameValue -Name 'Execute'
	Get-Command -Name 'pwsh' -CommandType 'Application' |
		Format-Table -Property @('Path', 'Version', 'Visibility') -AutoSize -Wrap
	Write-NameValue -Name 'System' -Value "$($PSVersionTable.Platform), $($PSVersionTable.OS)"
	Write-NameValue -Name 'Edition' -Value $PSVersionTable.PSEdition
	Write-NameValue -Name 'Version' -Value $PSVersionTable.PSVersion
	Write-NameValue -Name 'Host'
	$Host
	Write-NameValue -Name 'UI'
	$Host.UI.RawUI
	Exit-GitHubActionsLogGroup
	([Ordered]@{
		clamdscan = 'ClamAV Scan Daemon'
		clamscan = 'ClamAV Scan'
		freshclam = 'FreshClam (ClamAV Updater)'
		git = 'Git'
		'git-lfs' = 'Git LFS'
		node = 'NodeJS'
		yara = 'YARA'
	}).GetEnumerator() |
		ForEach-Object -Process {
			Enter-GitHubActionsLogGroup -Title "$($_.Value) (``$($_.Name)``): "
			Write-NameValue -Name 'Execute'
			Get-Command -Name $_.Name -CommandType 'Application' |
				Format-Table -Property @('Path', 'Version', 'Visibility') -AutoSize -Wrap
			Write-NameValue -Name 'VersionStdOut'
			Invoke-Expression -Command "$($_.Name) --version"
			Exit-GitHubActionsLogGroup
		}
}
Export-ModuleMember -Function @(
	'Get-HardwareMeta',
	'Get-SoftwareMeta'
)
