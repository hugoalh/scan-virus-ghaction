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
	Write-Header2 -InputObject 'HWInfo'
	hwinfo --all
	Exit-GitHubActionsLogGroup
}
Function Get-SoftwareMeta {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Enter-GitHubActionsLogGroup -Title 'Software Information: '
	Write-Header2 -InputObject 'Environment Variables'
	Get-ChildItem -LiteralPath 'Env:\' |
		Format-Table -AutoSize -Wrap
	Write-Header2 -InputObject 'PowerShell (`pwsh`)'
	Write-NameValue -Name 'Execute'
	Get-Command -Name 'pwsh' -CommandType 'Application' |
		Format-List -Property '*'
	Write-NameValue -Name 'System' -Value "$($PSVersionTable.Platform), $($PSVersionTable.OS)"
	Write-NameValue -Name 'Edition' -Value $PSVersionTable.PSEdition
	Write-NameValue -Name 'Version' -Value $PSVersionTable.PSVersion
	([Ordered]@{
		clamdscan = 'ClamAV Scan Daemon'
		clamscan = 'ClamAV Scan'
		freshclam = 'FreshClam (ClamAV Updater)'
		git = 'Git'
		node = 'NodeJS'
		yara = 'YARA'
	}).GetEnumerator() |
		ForEach-Object -Process {
			Write-Header2 -InputObject "$($_.Value) (``$($_.Name)``)"
			Write-NameValue -Name 'Execute'
			Get-Command -Name $_.Name -CommandType 'Application' |
				Format-List -Property '*'
			Write-NameValue -Name 'VersionStdOut' -Value (Invoke-Expression -Command "$($_.Name) --version")
		}
	Exit-GitHubActionsLogGroup
}
Export-ModuleMember -Function @(
	'Get-HardwareMeta',
	'Get-SoftwareMeta'
)
