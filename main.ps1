[string]$OriginalPreference_ErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'Stop'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
enum FilterMode {
	Exclude = 0
	E = 0
	Ex = 0
	Include = 1
	I = 1
	In = 1
}
[bool]$ConclusionSetFail = $false
[bool]$LocalTarget = $false
[string[]]$NetworkTargets = @()
[UInt64]$TotalScanElements = 0
[UInt64]$TotalScanSizes = 0
[string]$YARARulesRoot = Join-Path -Path $PSScriptRoot -ChildPath 'yara-rules'
[string[]]$YARARulesIndexRaw = Get-Content -Path (Join-Path -Path $YARARulesRoot -ChildPath 'index.tsv') -Encoding UTF8NoBOM
[pscustomobject[]]$YARARulesIndex = ConvertFrom-Csv -InputObject $YARARulesIndexRaw[1..$YARARulesIndexRaw.Count] -Delimiter "`t" -Header ($YARARulesIndexRaw[0] -split "`t")
function Test-StringIsURL {
	[CmdletBinding()][OutputType([bool])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$InputObject
	)
	$URIObject = $InputObject -as [System.URI]
	return (($null -ne $URIObject.AbsoluteURI) -and ($InputObject -match '^https?:\/\/'))
}
function Write-OptimizePSList {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$InputObject
	)
	[string]$OutputObject = $InputObject -replace '(?:\r?\n)+$', ''
	if ($OutputObject.Length -gt 0) {
		Write-Host -Object $OutputObject
	}
}
function Write-OptimizePSTable {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$InputObject
	)
	[string]$OutputObject = $InputObject -replace '^(?:\r?\n)+|(?:\r?\n)+$', ''
	if ($OutputObject.Length -gt 0) {
		Write-Host -Object $OutputObject
	}
}
Enter-GHActionsLogGroup -Title 'System volume:'
Write-OptimizePSTable -InputObject (Get-PSDrive | Out-String)
Exit-GHActionsLogGroup
Enter-GHActionsLogGroup -Title 'Import inputs.'
[string]$Targets = (Get-GHActionsInput -Name 'targets' -Trim) ?? (Get-GHActionsInput -Name 'target' -Trim)
if ($Targets -match '^\.\/$') {
	$LocalTarget = $true
} else {
	[string[]]$NetworkTargetsRaw = $Targets -split ";|\r?\n"
	$NetworkTargetsRaw | ForEach-Object -Process {
		return $_.Trim()
	} | Sort-Object | ForEach-Object -Process {
		if ($_.Length -gt 0) {
			if (Test-StringIsURL -InputObject $_) {
				$NetworkTargets += $_
			} else {
				Write-GHActionsWarning -Message "Input ``targets``'s value ``$_`` is not a valid target!"
			}
		}
	}
}
[bool]$Deep = [bool]::Parse((Get-GHActionsInput -Name 'deep' -Require -Trim))
[bool]$ClamAVEnable = [bool]::Parse((Get-GHActionsInput -Name 'clamav_enable' -Require -Trim))
[bool]$YARAEnable = [bool]::Parse((Get-GHActionsInput -Name 'yara_enable' -Require -Trim))
[string[]]$YARARulesFilterList = (Get-GHActionsInput -Name 'yara_rulesfilter_list' -Trim) -split ";|\r?\n"
[FilterMode]$YARARulesFilterMode = Get-GHActionsInput -Name 'yara_rulesfilter_mode' -Require -Trim
[bool]$YARAWarning = [bool]::Parse((Get-GHActionsInput -Name 'yara_warning' -Require -Trim))
[pscustomobject[]]$YARARulesFinal = @()
switch ($YARARulesFilterMode.GetHashCode()) {
	0 {
		foreach ($YARARule in $YARARulesIndex) {
			[bool]$Pass = $true
			foreach ($YARARuleFilter in $YARARulesFilterList) {
				if ($YARARule.Name -like $YARARuleFilter) {
					$Pass = $false
				}
			}
			if ($Pass) {
				$YARARulesFinal += $YARARule
			}
		}
		break
	}
	1 {
		foreach ($YARARule in $YARARulesIndex) {
			[bool]$Pass = $false
			foreach ($YARARuleFilter in $YARARulesFilterList) {
				if ($YARARule.Name -like $YARARuleFilter) {
					$Pass = $true
				}
			}
			if ($Pass) {
				$YARARulesFinal += $YARARule
			}
		}
		break
	}
}
Write-OptimizePSList -InputObject ([ordered]@{
	Targets = $LocalTarget ? '*Local*' : ($NetworkTargets -join ',')
	Deep = $Deep
	ClamAV_Enable = $ClamAVEnable
	YARA_Enable = $YARAEnable
	YARA_Rules_All = $YARARulesIndex.Name -join ', '
	YARA_Rules_All_Count = ($YARARulesIndex.Name).Count
	YARA_Rules_Filter_List = $YARARulesFilterList -join ', '
	YARA_Rules_Filter_List_Count = $YARARulesFilterList.Count
	YARA_Rules_Filter_Mode = $YARARulesFilterMode
	YARA_Rules_Final = $YARARulesFinal.Name -join ', '
	YARA_Rules_Final_Count = ($YARARulesFinal.Name).Count
	YARA_Warning = $YARAWarning
} | Format-List -Property 'Value' -GroupBy 'Name' | Out-String)
Exit-GHActionsLogGroup
if (($LocalTarget -eq $false) -and ($NetworkTargets.Count -eq 0)) {
	Write-GHActionsFail -Message 'Input `targets` does not have valid target!'
}
if ($true -notin @($ClamAVEnable, $YARAEnable)) {
	Write-GHActionsFail -Message 'No anti virus software enable!'
}
Enter-GHActionsLogGroup -Title 'Update system software.'
try {
	Invoke-Expression -Command 'apt-get --assume-yes update'
	Invoke-Expression -Command 'apt-get --assume-yes upgrade'
} catch {  }
Exit-GHActionsLogGroup
if ($ClamAVEnable) {
	Enter-GHActionsLogGroup -Title 'Update ClamAV via FreshClam.'
	try {
		Invoke-Expression -Command 'freshclam'
	} catch {  }
	Exit-GHActionsLogGroup
	Enter-GHActionsLogGroup -Title 'Start ClamAV daemon.'
	Invoke-Expression -Command 'clamd'
	Exit-GHActionsLogGroup
}
function Invoke-ScanVirus {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Session
	)
	Write-Host -Object "Begin scan session `"$Session`"."
	[pscustomobject[]]$ElementsRaw = Get-ChildItem -Path $env:GITHUB_WORKSPACE -Recurse -Force
	[pscustomobject[]]$Elements = $ElementsRaw | Sort-Object
	$script:TotalScanElements += $Elements.Count
	[string[]]$ElementsListClamAV = @()
	[string[]]$ElementsListYARA = @()
	[pscustomobject[]]$ElementsListDisplay = @()
	$Elements | ForEach-Object {
		[bool]$ElementIsDirectory = Test-Path -Path $_.FullName -PathType Container
		[hashtable]$ElementListDisplay = @{
			Element = $_.FullName -replace "$([regex]::Escape($env:GITHUB_WORKSPACE))\/", './'
			Flags = $ElementIsDirectory ? 'D' : ''
		}
		$ElementsListClamAV += $_.FullName
		if ($ElementIsDirectory -eq $false) {
			$ElementsListYARA += $_.FullName
			[UInt64]$ElementSizes = $_.Length
			$ElementListDisplay.Sizes = $ElementSizes
			$script:TotalScanSizes += $ElementSizes
		}
		$ElementsListDisplay += [pscustomobject]$ElementListDisplay
	}
	Enter-GHActionsLogGroup -Title "Elements ($Session) - $($Elements.Count):"
	Write-OptimizePSTable -InputObject ($ElementsListDisplay | Format-Table -Property @('Element', 'Flags', @{Expression = 'Sizes'; Alignment = 'Right'}) -AutoSize -Wrap | Out-String)
	Exit-GHActionsLogGroup
	if ($Elements.Count -gt 0) {
		if ($ClamAVEnable) {
			[string]$ElementsListClamAVPath = (New-TemporaryFile).FullName
			Set-Content -Path $ElementsListClamAVPath -Value ($ElementsListClamAV -join "`n") -NoNewline -Encoding UTF8NoBOM
			Enter-GHActionsLogGroup -Title "ClamAV result ($Session):"
			[string[]]$ClamAVOutput = Invoke-Expression -Command "clamdscan --fdpass --file-list `"$ElementsListClamAVPath`" --multiscan"
			[string[]]$ClamAVResultRaw = @()
			$ClamAVOutput | ForEach-Object -Process {
				if ($_ -notmatch ': OK$') {
					$ClamAVResultRaw += $_ -replace "$([regex]::Escape($env:GITHUB_WORKSPACE))\/", './'
				}
			}
			[string]$ClamAVResult = ($ClamAVResultRaw -join "`n").Trim()
			if ($ClamAVResult.Length -gt 0) {
				Write-Host -Object $ClamAVResult
			}
			if ($LASTEXITCODE -eq 1) {
				Write-GHActionsError -Message "Found issues in session `"$Session`" via ClamAV!"
				$script:ConclusionSetFail = $true
			} elseif ($LASTEXITCODE -gt 1) {
				Write-GHActionsError -Message "Unexpected ClamAV result ``$LASTEXITCODE`` in session `"$Session`"!"
				$script:ConclusionSetFail = $true
			}
			Exit-GHActionsLogGroup
			Remove-Item -Path $ElementsListClamAVPath -Force -Confirm:$false
		}
		if ($YARAEnable) {
			[string]$ElementsListYARAPath = (New-TemporaryFile).FullName
			Set-Content -Path $ElementsListYARAPath -Value ($ElementsListYARA -join "`n") -NoNewline -Encoding UTF8NoBOM
			[hashtable]$YARAResultRaw = @{}
			Enter-GHActionsLogGroup -Title "YARA result ($Session):"
			foreach ($YARARule in $YARARulesFinal) {
				[string[]]$YARAOutput = Invoke-Expression -Command "yara --scan-list$($YARAWarning ? ' --no-warnings ' : ' ')`"$(Join-Path -Path $YARARulesRoot -ChildPath $YARARule.Entrypoint)`" `"$ElementsListYARAPath`""
				$YARAOutput | ForEach-Object -Process {
					if ($_ -match "^.+? $([regex]::Escape($env:GITHUB_WORKSPACE))\/.+$") {
						Write-GHActionsDebug -Message "$($YARARule.Name)/$_"
						[string]$Rule, [string]$Element = $_ -split "(?<=^.+?) "
						$Element = $Element -replace "$([regex]::Escape($env:GITHUB_WORKSPACE))\/", './'
						if ($null -eq $YARAResultRaw[$Element]) {
							$YARAResultRaw[$Element] = @()
						}
						$YARAResultRaw[$Element] += "$($YARARule.Name)/$Rule"
					} elseif ($_.Length -gt 0) {
						Write-Host -Object $_
					}
				}
				if ($LASTEXITCODE -gt 0) {
					Write-GHActionsError -Message "Unexpected YARA `"$($YARARule.Name)`" result ``$LASTEXITCODE`` in session `"$Session`"!"
					$script:ConclusionSetFail = $true
				}
			}
			if ($YARAResultRaw.Count -gt 0) {
				[hashtable]$YARAResult = @{}
				$YARAResultRaw.GetEnumerator() | ForEach-Object -Process {
					$YARAResult[$_.Name] = $_.Value -join ', '
				}
				Write-OptimizePSList -InputObject ($YARAResult.GetEnumerator() | Sort-Object -Property 'Name' | Format-List -Property 'Value' -GroupBy 'Name' | Out-String)
				Write-GHActionsError -Message "Found issues in session `"$Session`" via YARA!"
				$script:ConclusionSetFail = $true
			}
			Exit-GHActionsLogGroup
			Remove-Item -Path $ElementsListYARAPath -Force -Confirm:$false
		}
	}
	Write-Host -Object "End scan session $Session."
}
if ($LocalTarget) {
	Invoke-ScanVirus -Session 'Current'
	if ($Deep) {
		if (Test-Path -Path '.\.git') {
			Write-Host -Object 'Import Git information.'
			[string[]]$GitCommits = Invoke-Expression -Command 'git --no-pager log --all --format=%H --reflog --reverse'
			if ($GitCommits.Count -le 1) {
				Write-GHActionsWarning -Message "Current Git repository has only $($GitCommits.Count) commits! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow. (IMPORTANT: ``Re-run all jobs`` or ``Re-run this workflow`` cannot apply the modified workflow!)"
			}
			for ($GitCommitsIndex = 0; $GitCommitsIndex -lt $GitCommits.Count; $GitCommitsIndex++) {
				[string]$GitCommit = $GitCommits[$GitCommitsIndex]
				[string]$GitSession = "Commit #$($GitCommitsIndex + 1)/$($GitCommits.Count) - $GitCommit"
				Enter-GHActionsLogGroup -Title "Git checkout for session `"$GitSession`"."
				try {
					Invoke-Expression -Command "git checkout $GitCommit --force --quiet"
				} catch {  }
				if ($LASTEXITCODE -eq 0) {
					Exit-GHActionsLogGroup
					Invoke-ScanVirus -Session $GitSession
				} else {
					Write-GHActionsError -Message "Unexpected Git checkout result ``$LASTEXITCODE`` in session `"$GitSession`"!"
					$ConclusionSetFail = $true
					Exit-GHActionsLogGroup
				}
			}
		} else {
			Write-GHActionsWarning -Message 'Unable to deep scan workspace due to it is not a Git repository! If this is incorrect, probably Git data is broken and/or invalid.'
		}
	}
} else {
	[string[]]$UselessElements = Get-ChildItem -Path $env:GITHUB_WORKSPACE -Force -Name
	if ($UselessElements.Count -gt 0) {
		Write-GHActionsWarning -Message 'Require a clean workspace when target is network!'
		Write-Host -Object 'Clean workspace.'
		$UselessElements | ForEach-Object -Process {
			Remove-Item -Path (Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $_) -Recurse -Force -Confirm:$false
		}
	}
	$NetworkTargets | ForEach-Object -Process {
		Enter-GHActionsLogGroup -Title "Fetch file `"$_`"."
		[string]$NetworkTemporaryFileFullPath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath (New-Guid).Guid
		try {
			Invoke-WebRequest -Uri $_ -UseBasicParsing -Method Get -OutFile $NetworkTemporaryFileFullPath
		} catch {
			Write-GHActionsError -Message "Unable to fetch file `"$_`"!"
			continue
		}
		Exit-GHActionsLogGroup
		Invoke-ScanVirus -Session $_
		Remove-Item -Path $NetworkTemporaryFileFullPath -Force -Confirm:$false
	}
}
Enter-GHActionsLogGroup -Title "Statistics:"
Write-OptimizePSTable -InputObject ([ordered]@{
	TotalScanElements = $TotalScanElements
	TotalScanSizes_B = $TotalScanSizes
	TotalScanSizes_KB = $TotalScanSizes / 1KB
	TotalScanSizes_MB = $TotalScanSizes / 1MB
	TotalScanSizes_GB = $TotalScanSizes / 1GB
	TotalScanSizes_TB = $TotalScanSizes / 1TB
} | Format-Table -Property @('Name', @{Expression = 'Value'; Alignment = 'Right'}) -AutoSize -Wrap | Out-String)
Exit-GHActionsLogGroup
if ($ClamAVEnable) {
	Enter-GHActionsLogGroup -Title 'Stop ClamAV daemon.'
	Get-Process -Name '*clamd*' | Stop-Process
	Exit-GHActionsLogGroup
}
$ErrorActionPreference = $OriginalPreference_ErrorAction
if ($ConclusionSetFail) {
	exit 1
}
exit 0
