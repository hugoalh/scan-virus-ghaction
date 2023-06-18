#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'splat-parameter'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Function Show-EnvironmentVariable {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Enter-GitHubActionsLogGroup -Title 'Environment Variable: '
	Get-ChildItem -LiteralPath 'Env:\' |
		ForEach-Object -Begin {
			$Result = [Ordered]@{}
		} -Process {
			$Result.($_.Name) = (
				$_.Name -iin @('ACTIONS_RUNTIME_TOKEN') -or
				$_.Name -imatch '_TOKEN$'
			) ? '***' : $_.Value
		} -End {
			[PSCustomObject]$Result |
				Format-List |
				Out-String -Width 120 |
				Write-Host
		}
	Exit-GitHubActionsLogGroup
}
Function Show-SoftwareMeta {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Enter-GitHubActionsLogGroup -Title 'PowerShell (`pwsh`): '
	[PSCustomObject]@{
		Path = Get-Command -Name 'pwsh' -CommandType 'Application' |
			Select-Object -ExpandProperty 'Path' |
			Join-String -Separator ', '
		System = "$($PSVersionTable.Platform); $($PSVersionTable.OS)"
		Edition = $PSVersionTable.PSEdition
		Version = $PSVersionTable.PSVersion.ToString()
		Host = $Host |
			Out-String -Width 80
		UI = $Host.UI.RawUI |
			Out-String -Width 80
		Module = Get-InstalledModule |
			Format-Table -Property @('Name', 'Version', 'Description') -AutoSize -Wrap |
			Out-String -Width 80
	} |
		Format-List |
		Out-String -Width 120 |
		Write-Host
	Exit-GitHubActionsLogGroup
	[Hashtable[]]$BinList = @(
		@{ Bin = 'git'; Name = 'Git' },
		@{ Bin = 'git-lfs'; Name = 'Git LFS' }
		# @{ Bin = 'node'; Name = 'NodeJS' }
	)
	If ($ClamAVBundle) {
		$BinList += @(
			@{ Bin = 'clamd'; Name = 'ClamAV Daemon' },
			@{ Bin = 'clamdscan'; Name = 'ClamAV Scan Daemon' },
			@{ Bin = 'clamscan'; Name = 'ClamAV Scan' },
			@{ Bin = 'freshclam'; Name = 'FreshClam (ClamAV Updater)' }
		)
	}
	If ($YaraBundle) {
		$BinList += @(
			@{ Bin = 'yara'; Name = 'YARA' }
			# @{ Bin = 'yarac'; Name = 'YARA Compiler' }
		)
	}
	$BinList |
		ForEach-Object -Process { [PSCustomObject]$_ } |
		Sort-Object -Property 'Bin' |
		ForEach-Object -Process {
			Enter-GitHubActionsLogGroup -Title "$($_.Name) (``$($_.Bin)``): "
			[PSCustomObject]@{
				Path = Get-Command -Name $_.Bin -CommandType 'Application' |
					Select-Object -ExpandProperty 'Path' |
					Join-String -Separator ', '
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
	'Show-EnvironmentVariable',
	'Show-SoftwareMeta'
)
