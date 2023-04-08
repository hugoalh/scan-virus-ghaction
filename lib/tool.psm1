#Requires -PSEdition Core -Version 7.3
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'assets',
		'display'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
[RegEx]$GitHubActionsWorkspaceRootRegEx = "$([RegEx]::Escape($Env:GITHUB_WORKSPACE))\/"
Function Invoke-ClamAV {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Elements', 'File', 'Files')][String[]]$Element
	)
	[Hashtable]$Result = @{
		ElementFound = @{}
		ErrorMessage = @()
		ExitCode = 0
		Output = @()
	}
	$ElementScanListFile = New-TemporaryFile
	Set-Content -LiteralPath $ElementScanListFile -Value (
		$Element |
			Join-String -Separator "`n"
	) -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
	Try {
		$Result.Output += clamdscan --fdpass --file-list="$($ElementScanListFile.FullName)" --multiscan
	}
	Catch {
		$Result.ExitCode = $LASTEXITCODE
		$Result.ErrorMessage += $_
		Write-Output -InputObject $Result
		Return
	}
	Finally {
		Remove-Item -LiteralPath $ElementScanListFile -Force -Confirm:$False
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
			[String]$ElementIssue, [String]$Signature = ($OutputLine -ireplace ' FOUND$', '') -isplit '(?<=^.+?): '
			If ($Null -ieq $Result.ElementFound[$ElementIssue]) {
				$Result.ElementFound[$ElementIssue] = @()
			}
			If ($Signature -inotin $Result.ElementFound[$ElementIssue]) {
				$Result.ElementFound[$ElementIssue] += $Signature
			}
			Continue
		}
		If ($OutputLine.Trim().Length -igt 0) {
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
		[Parameter(Mandatory = $True, Position = 0)][Alias('Elements', 'File', 'Files')][String[]]$Element,
		[Parameter(Mandatory = $True, Position = 1)][Alias('Rules')][PSCustomObject[]]$Rule
	)
	[Hashtable]$Result = @{
		ElementFound = @{}
		ErrorMessage = @()
		ExitCode = 0
		Output = @()
	}
	$ElementScanListFile = New-TemporaryFile
	Set-Content -LiteralPath $ElementScanListFile -Value (
		$Element |
			Join-String -Separator "`n"
	) -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
	ForEach ($RuleEntry In $Rule) {
		Try {
			$Result.Output += yara --scan-list "$(Join-Path -Path $YaraRulesAssetsRoot -ChildPath $RuleEntry.Path)" "$($ElementScanListFile.FullName)"
		}
		Catch {
			$Result.ExitCode = [Math]::Max($Result.ExitCode, $LASTEXITCODE)
			$Result.ErrorMessage += $_
			Continue
		}
		Finally {
			Remove-Item -LiteralPath $ElementScanListFile -Force -Confirm:$False
		}
		$Result.ExitCode = [Math]::Max($Result.ExitCode, $LASTEXITCODE)
	}
	ForEach ($OutputLine In $Result.Output) {
		If ($OutputLine -imatch "^.+? $GitHubActionsWorkspaceRootRegEx.+$") {
			[String]$Rule, [String]$ElementIssue = $OutputLine -isplit "(?<=^.+?) $GitHubActionsWorkspaceRootRegEx"
			[String]$YaraRuleName = "$($YaraRule.Name)/$Rule"
			If ($Null -ieq $Result.ElementFound[$ElementIssue]) {
				$Result.ElementFound[$ElementIssue] = @()
			}
			If ($YaraRuleName -inotin $Result.ElementFound[$ElementIssue]) {
				$Result.ElementFound[$ElementIssue] += $YaraRuleName
			}
			Continue
		}
		If ($OutputLine.Trim().Length -igt 0) {
			$Result.ErrorMessage += $OutputLine
			Continue
		}
	}
	Write-Output -InputObject $Result
}
Export-ModuleMember -Function @(
	'Invoke-ClamAV',
	'Invoke-Yara'
)
