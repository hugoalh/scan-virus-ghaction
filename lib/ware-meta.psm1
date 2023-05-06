#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
<#
Import-Module -Name (
	@(
		'display'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
#>
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
				Out-String -Width ([Int]::MaxValue) |
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
			Out-String -Width ([Int]::MaxValue)
		UI = $Host.UI.RawUI |
			Out-String -Width ([Int]::MaxValue)
		Module = Get-InstalledModule |
			Format-Table -Property @('Name', 'Version', 'Description') -AutoSize |
			Out-String -Width ([Int]::MaxValue)
	} |
		Format-List |
		Out-String -Width ([Int]::MaxValue) |
		Write-Host
	<#
	Write-NameValue -Name 'Path' -Value (
		Get-Command -Name 'pwsh' -CommandType 'Application' |
			Select-Object -ExpandProperty 'Path' |
			Join-String -Separator ', ' -FormatString '`{0}`'
	)
	Write-NameValue -Name 'System' -Value "$($PSVersionTable.Platform); $($PSVersionTable.OS)"
	Write-NameValue -Name 'Edition' -Value $PSVersionTable.PSEdition
	Write-NameValue -Name 'Version' -Value $PSVersionTable.PSVersion.ToString()
	Write-NameValue -Name 'Host' -Value (
		$Host |
			Out-String -Width ([Int]::MaxValue)
	) -NewLine
	Write-NameValue -Name 'UI' -Value (
		$Host.UI.RawUI |
			Out-String -Width ([Int]::MaxValue)
	) -NewLine
	Write-NameValue -Name 'Module' -Value (
		Get-InstalledModule |
			Format-Table -Property @('Name', 'Version', 'Description') -AutoSize |
			Out-String -Width ([Int]::MaxValue)
	) -NewLine
	#>
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
			}
			<#
			Write-NameValue -Name 'Path' -Value (
				Get-Command -Name $_.Bin -CommandType 'Application' |
					Select-Object -ExpandProperty 'Path' |
					Join-String -Separator ', ' -FormatString '`{0}`'
			)
			Write-NameValue -Name 'VersionStdOut' -Value (Invoke-Expression -Command "$($_.Bin) --version") -NewLine
			#>
			Exit-GitHubActionsLogGroup
		}
}
Export-ModuleMember -Function @(
	'Get-WareMeta'
)
