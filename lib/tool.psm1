#Requires -PSEdition Core -Version 7.3
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
[RegEx]$GitHubActionsWorkspaceRootRegEx = "$([RegEx]::Escape($Env:GITHUB_WORKSPACE))\/"
Import-Module -Name (
	@(
		'assets',
		'display'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Function Invoke-ClamAV {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Elements', 'File', 'Files')][String[]]$Element
	)
	$ElementScanList = New-TemporaryFile
	Set-Content -LiteralPath $ElementScanList -Value (
		$Element |
			Join-String -Separator "`n"
	) -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
	Try {
		[String[]]$Output = clamdscan --fdpass --file-list="$($ElementScanList.FullName)" --multiscan
		[Int32]$ExitCode = $LASTEXITCODE
	}
	Catch {
		Write-GitHubActionsError -Message "Unexpected issues when invoke ClamAV (SessionID: $SessionId): $_"
		Exit-GitHubActionsLogGroup
		Exit 1
	}
	$Output |
		Write-GitHubActionsDebug
	[String[]]$ResultError = @()
	[Hashtable]$ResultFound = @{}
	ForEach ($Line In (
		$Output |
			ForEach-Object -Process { $_ -ireplace "^$GitHubActionsWorkspaceRootRegEx", '' }
	)) {
		If ($Line -imatch '^[-=]+\s*SCAN SUMMARY\s*[-=]+$') {
			Break
		}
		If (
			($Line -imatch ': OK$') -or
			($Line -imatch '^\s*$')
		) {
			Continue
		}
		If ($Line -imatch ': .+ FOUND$') {
			[String]$ElementIssue = $Line -ireplace ' FOUND$', ''
			[String]$Element, [String]$Signature = $ElementIssue -isplit '(?<=^.+?): '
			If ($Null -ieq $ResultFound[$Element]) {
				$ResultFound[$Element] = @()
			}
			If ($Signature -inotin $ResultFound[$Element]) {
				$ResultFound[$Element] += $Signature
			}
			Continue
		}
		$ResultError += $Line
	}
	If ($ResultFound.Count -igt 0) {
		$ResultFound.GetEnumerator() |
			Sort-Object -Property 'Name' |
			ForEach-Object -Process {
				[String[]]$IssueSignatures = $_.Value |
					Sort-Object -Unique -CaseSensitive
				Write-NameValue -Name "$($_.Name) [$($IssueSignatures.Count)]" -Value (
					$IssueSignatures |
						Join-String -Separator ', '
				)
			}
		Write-GitHubActionsError -Message "Found issues in session `"$SessionTitle`" via ClamAV [$($ResultFound.Count)]: `n$(
			$ResultFound.GetEnumerator().Name |
				Sort-Object |
				Join-String -Separator ', '
		)"
		If ($SessionId -inotin $Script:StatisticsIssuesSessions.ClamAV) {
			$Script:StatisticsIssuesSessions.ClamAV += $SessionId
		}
	}
	If ($ClamAVResultError.Count -igt 0) {
		Write-GitHubActionsError -Message "Unexpected ClamAV result ``$ExitCode`` in session `"$SessionTitle`":`n$($ClamAVResultError -join "`n")"
		If ($SessionId -inotin $Script:StatisticsIssuesSessions.ClamAV) {
			$Script:StatisticsIssuesSessions.ClamAV += $SessionId
		}
	}
	Remove-Item -LiteralPath $ElementScanList -Force -Confirm:$False
}
Function Invoke-Yara {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Elements', 'File', 'Files')][String[]]$Element,
		[Parameter(Mandatory = $True, Position = 1)][Alias('Rules')][PSCustomObject[]]$Rule
	)
	$ElementScanList = New-TemporaryFile
	Set-Content -LiteralPath $ElementScanList -Value (
		$Element |
			Join-String -Separator "`n"
	) -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
	[Hashtable]$ResultFound = @{}
	ForEach ($RuleEntry In $Rule) {
		Try {
			[String[]]$Output = yara --scan-list "$(Join-Path -Path $YaraRulesAssetsRoot -ChildPath $RuleEntry.Location)" "$($ElementScanList.FullName)"
			[Int32]$ExitCode = $LASTEXITCODE
		}
		Catch {
			Write-GitHubActionsError -Message "Unexpected issues when invoke YARA (SessionID: $SessionId): $_"
			Exit-GitHubActionsLogGroup
			Exit 1
		}
	}
	Remove-Item -LiteralPath $ElementScanList -Force -Confirm:$False
}
Export-ModuleMember -Function @(
	'Invoke-ClamAV',
	'Invoke-Yara'
)
