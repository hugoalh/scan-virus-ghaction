#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'assets',
		'display'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
[RegEx]$GitHubActionsWorkspaceRootRegEx = [RegEx]::Escape("$($Env:GITHUB_WORKSPACE)/")
Function Invoke-ClamAVScan {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Targets')][String[]]$Target
	)
	[Hashtable]$Result = @{
		ErrorMessage = @()
		ExitCode = 0
		Found = @{}
		Output = @()
	}
	$TargetListFile = New-TemporaryFile
	Set-Content -LiteralPath $TargetListFile -Value (
		$Target |
			Join-String -Separator "`n"
	) -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
	Try {
		$Result.Output += Invoke-Expression -Command "clamdscan --fdpass --file-list=`"$($TargetListFile.FullName)`" --multiscan"
	}
	Catch {
		$Result.ExitCode = $LASTEXITCODE
		$Result.ErrorMessage += $_
		Write-Output -InputObject $Result
		Return
	}
	Finally {
		Remove-Item -LiteralPath $TargetListFile -Force -Confirm:$False
	}
	$Result.ExitCode = $LASTEXITCODE
	ForEach ($OutputLine In (
		$Result.Output |
			ForEach-Object -Process { $_ -ireplace "^$GitHubActionsWorkspaceRootRegEx", '' }
	)) {
		If ($OutputLine -imatch '^[-=]+\s*SCAN SUMMARY\s*[-=]+$') {
			Break
		}
		If (
			($OutputLine -imatch ': OK$') -or
			($OutputLine -imatch '^\s*$')
		) {
			Continue
		}
		If ($OutputLine -imatch ': .+ FOUND$') {
			[String]$Element, [String]$Signature = ($OutputLine -ireplace ' FOUND$', '') -isplit '(?<=^.+?): '
			If ($Null -ieq $Result.Found[$Element]) {
				$Result.Found[$Element] = @()
			}
			If ($Signature -inotin $Result.Found[$Element]) {
				$Result.Found[$Element] += $Signature
			}
			Continue
		}
		If ($OutputLine.Length -gt 0) {
			$Result.ErrorMessage += $OutputLine
			Continue
		}
	}
	Write-Output -InputObject $Result
}
Function Invoke-Yara {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Targets')][String[]]$Target,
		[Parameter(Mandatory = $True, Position = 1)][PSCustomObject]$Asset
	)
	[Hashtable]$Result = @{
		ErrorMessage = @()
		ExitCode = 0
		Found = @{}
		Output = @()
	}
	$TargetListFile = New-TemporaryFile
	Set-Content -LiteralPath $TargetListFile -Value (
		$Target |
			Join-String -Separator "`n"
	) -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
	Try {
		$Result.Output += Invoke-Expression -Command "yara --scan-list `"$($Entry.FilePath)`" `"$($TargetListFile.FullName)`""
	}
	Catch {
		$Result.ExitCode = $LASTEXITCODE
		$Result.ErrorMessage += $_
		Write-Output -InputObject $Result
		Return
	}
	Finally {
		Remove-Item -LiteralPath $TargetListFile -Force -Confirm:$False
	}
	$Result.ExitCode = $LASTEXITCODE
	ForEach ($OutputLine In $Result.Output) {
		If ($OutputLine -imatch "^.+? $GitHubActionsWorkspaceRootRegEx.+$") {
			[String]$Rule, [String]$Element = $OutputLine -isplit "(?<=^.+?) $GitHubActionsWorkspaceRootRegEx"
			If ($Null -ieq $Result.Found[$Element]) {
				$Result.Found[$Element] = @()
			}
			If ($Rule -inotin $Result.Found[$Element]) {
				$Result.Found[$Element] += $Rule
			}
			Continue
		}
		If ($OutputLine.Length -gt 0) {
			$Result.ErrorMessage += $OutputLine
			Continue
		}
	}
	Write-Output -InputObject $Result
}
Function Start-ClamAVDaemon {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Enter-GitHubActionsLogGroup -Title 'Start ClamAV daemon.'
	Try {
		clamd
	}
	Catch {
		Write-GitHubActionsFail -Message "Unexpected issues when start ClamAV daemon: $_" -Finally {
			Exit-GitHubActionsLogGroup
		}
	}
	Exit-GitHubActionsLogGroup
}
Function Stop-ClamAVDaemon {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Enter-GitHubActionsLogGroup -Title 'Stop ClamAV daemon.'
	Get-Process -Name 'clamd' -ErrorAction 'Continue' |
		Stop-Process
	Exit-GitHubActionsLogGroup
}
Export-ModuleMember -Function @(
	'Invoke-ClamAVScan',
	'Invoke-Yara',
	'Start-ClamAVDaemon',
	'Stop-ClamAVDaemon'
)
