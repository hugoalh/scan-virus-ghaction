#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Function Get-WareMeta {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Enter-GitHubActionsLogGroup -Title 'Hardware: '
	hwinfo --all
	Exit-GitHubActionsLogGroup
	Enter-GitHubActionsLogGroup -Title 'Environment Variables: '
	Get-ChildItem -LiteralPath 'Env:\' |
		ForEach-Object -Begin {
			$Result = [Ordered]@{}
		} -Process {
			If (
				$_.Name -iin @('ACTIONS_RUNTIME_TOKEN') -or
				$_.Name -imatch '_TOKEN$'
			) {
				$Result.($_.Name) = '***'
			}
			Else {
				$Result.($_.Name) = $_.Value
			}
		} -End {
			[PSCustomObject]$Result |
				Format-List |
				Out-String -Width 120 |
				Write-Host
		}
	Exit-GitHubActionsLogGroup
	Enter-GitHubActionsLogGroup -Title 'PowerShell (`pwsh`): '
	[PSCustomObject]@{
		Path = Get-Command -Name 'pwsh' -CommandType 'Application' |
			Select-Object -ExpandProperty 'Path' |
			Join-String -Separator ', ' -FormatString '`{0}`'
		System = "$($PSVersionTable.Platform); $($PSVersionTable.OS)"
		Edition = $PSVersionTable.PSEdition
		Version = $PSVersionTable.PSVersion.ToString()
		Host = $Host |
			Out-String -Width 120
		UI = $Host.UI.RawUI |
			Out-String -Width 120
		Module = Get-InstalledModule |
			Format-Table -Property @('Name', 'Version', 'Description') -AutoSize -Wrap |
			Out-String -Width 120
	} |
		Format-List |
		Out-String -Width 120 |
		Write-Host
	Exit-GitHubActionsLogGroup
	@(
		@{ Bin = 'clamdscan'; Name = 'ClamAV Scan Daemon' },
		@{ Bin = 'clamscan'; Name = 'ClamAV Scan' },
		@{ Bin = 'freshclam'; Name = 'FreshClam (ClamAV Updater)' },
		@{ Bin = 'git'; Name = 'Git' },
		@{ Bin = 'git-lfs'; Name = 'Git LFS' },
		@{ Bin = 'node'; Name = 'NodeJS' },
		@{ Bin = 'yara'; Name = 'YARA' }
		@{ Bin = 'yarac'; Name = 'YARA Compiler' }
	) |
		ForEach-Object -Process {
			Enter-GitHubActionsLogGroup -Title "$($_.Name) (``$($_.Bin)``): "
			[PSCustomObject]@{
				Path = Get-Command -Name $_.Bin -CommandType 'Application' |
					Select-Object -ExpandProperty 'Path' |
					Join-String -Separator ', ' -FormatString '`{0}`'
				VersionStdOut = Invoke-Expression -Command "$($_.Bin) --version" |
					Join-String -Separator "`n"
			} |
				Format-List |
				Out-String -Width 120 |
				Write-Host
			Exit-GitHubActionsLogGroup
		}
}
Export-ModuleMember -Function @(
	'Get-WareMeta'
)
