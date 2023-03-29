#Requires -PSEdition Core -Version 7.3
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'display'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Function Get-WareMeta {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Enter-GitHubActionsLogGroup -Title 'Hardware Information: '
	hwinfo --all
	Exit-GitHubActionsLogGroup
	Enter-GitHubActionsLogGroup -Title 'Environment Variables: '
	Get-ChildItem -LiteralPath 'Env:\' |
		ForEach-Object -Process {
			If (
				$_.Name -iin @('ACTIONS_RUNTIME_TOKEN') -or
				$_.Name -imatch '_TOKEN$'
			) {
				[PSCustomObject]@{
					Name = $_.Name
					Value = '***'
				} |
					Write-Output
			}
			Else {
				[PSCustomObject]@{
					Name = $_.Name
					Value = $_.Value
				} |
					Write-Output
			}
		} |
		Format-Table -AutoSize |
		Out-String
	Exit-GitHubActionsLogGroup
	Enter-GitHubActionsLogGroup -Title 'PowerShell (`pwsh`): '
	Write-NameValue -Name 'Path' -Value (
		Get-Command -Name 'pwsh' -CommandType 'Application' |
			Select-Object -ExpandProperty 'Path' |
			Join-String -Separator ', ' -FormatString '`{0}`'
	) -NewLine
	Write-NameValue -Name 'System' -Value "$($PSVersionTable.Platform); $($PSVersionTable.OS)"
	Write-NameValue -Name 'Edition' -Value $PSVersionTable.PSEdition
	Write-NameValue -Name 'Version' -Value $PSVersionTable.PSVersion
	Write-NameValue -Name 'Host' -Value $Host -NewLine
	Write-NameValue -Name 'UI' -Value $Host.UI.RawUI -NewLine
	Write-NameValue -Name 'Module' -Value (
		Get-InstalledModule |
			Format-Table -Property @('Name', 'Version', 'Description') -AutoSize |
			Out-String
	) -NewLine
	Exit-GitHubActionsLogGroup
	@(
		@{ Bin = 'clamdscan'; Name = 'ClamAV Scan Daemon' },
		@{ Bin = 'clamscan'; Name = 'ClamAV Scan' },
		@{ Bin = 'freshclam'; Name = 'FreshClam (ClamAV Updater)' },
		@{ Bin = 'git'; Name = 'Git' },
		@{ Bin = 'git-lfs'; Name = 'Git LFS' },
		@{ Bin = 'node'; Name = 'NodeJS' },
		@{ Bin = 'yara'; Name = 'YARA' }
	) |
		ForEach-Object -Process {
			Enter-GitHubActionsLogGroup -Title "$($_.Name) (``$($_.Bin)``): "
			Write-NameValue -Name 'Path' -Value (
				Get-Command -Name $_.Bin -CommandType 'Application' |
					Select-Object -ExpandProperty 'Path' |
					Join-String -Separator ', ' -FormatString '`{0}`'
			) -NewLine
			Write-NameValue -Name 'VersionStdOut' -Value (Invoke-Expression -Command "$($_.Bin) --version") -NewLine
			Exit-GitHubActionsLogGroup
		}
}
Export-ModuleMember -Function @(
	'Get-WareMeta'
)
