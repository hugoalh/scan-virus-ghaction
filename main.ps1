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
[UInt64]$TotalElementsAll = 0
[UInt64]$TotalElementsClamAV = 0
[UInt64]$TotalElementsYARA = 0
[UInt64]$TotalSizesAll = 0
[UInt64]$TotalSizesClamAV = 0
[UInt64]$TotalSizesYARA = 0
[string]$YARARulesRoot = Join-Path -Path $PSScriptRoot -ChildPath 'yara-rules'
[string[]]$YARARulesIndexRaw = Get-Content -Path (Join-Path -Path $YARARulesRoot -ChildPath 'index.tsv') -Encoding UTF8NoBOM
[pscustomobject[]]$YARARulesIndex = ConvertFrom-Csv -InputObject $YARARulesIndexRaw[1..$YARARulesIndexRaw.Count] -Delimiter "`t" -Header ($YARARulesIndexRaw[0] -split "`t")
function Format-GHActionsInputList {
	[CmdletBinding()][OutputType([string[]])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][AllowEmptyString()][string]$InputObject
	)
	[string[]]$Raw = $InputObject -split ";|\r?\n"
	[string[]]$Result = $Raw | ForEach-Object -Process {
		return $_.Trim()
	} | Where-Object -FilterScript {
		return ($_.Length -gt 0)
	}
	return $Result
}
function Get-GHActionsInputFilterList {
	[CmdletBinding()][OutputType([string[]])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Name
	)
	return Format-GHActionsInputList -InputObject (Get-GHActionsInput -Name $Name -Trim)
}
function Test-InputFilter {
	[CmdletBinding()][OutputType([bool])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Target,
		[Parameter(Mandatory = $true, Position = 1)][AllowEmptyCollection()][AllowNull()][string[]]$FilterList,
		[Parameter(Mandatory = $true, Position = 2)][FilterMode]$FilterMode
	)
	foreach ($Filter in $FilterList) {
		if ($Target -match $Filter) {
			switch ($FilterMode.GetHashCode()) {
				0 { return $false }
				1 { return $true }
			}
		}
	}
	switch ($FilterMode.GetHashCode()) {
		0 { return $true }
		1 { return $false }
	}
}
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
if ($Targets -match '^\.[\/\\]$') {
	$LocalTarget = $true
} else {
	Format-GHActionsInputList -InputObject $Targets | ForEach-Object -Process {
		if (Test-StringIsURL -InputObject $_) {
			$NetworkTargets += $_
		} else {
			Write-GHActionsWarning -Message "Input ``targets``'s value ``$_`` is not a valid target!"
		}
	}
}
$NetworkTargets = $NetworkTargets | Sort-Object
[bool]$Deep = [bool]::Parse((Get-GHActionsInput -Name 'deep' -Require -Trim))
[bool]$GitReverseSession = [bool]::Parse((Get-GHActionsInput -Name 'git_reversesession' -Require -Trim))
[bool]$ClamAVEnable = [bool]::Parse((Get-GHActionsInput -Name 'clamav_enable' -Require -Trim))
[string[]]$ClamAVFilesFilterList = Get-GHActionsInputFilterList -Name 'clamav_filesfilter_list'
[FilterMode]$ClamAVFilesFilterMode = Get-GHActionsInput -Name 'clamav_filesfilter_mode' -Require -Trim
[bool]$ClamAVMultiScan = [bool]::Parse((Get-GHActionsInput -Name 'clamav_multiscan' -Require -Trim))
[bool]$YARAEnable = [bool]::Parse((Get-GHActionsInput -Name 'yara_enable' -Require -Trim))
[string[]]$YARAFilesFilterList = Get-GHActionsInputFilterList -Name 'yara_filesfilter_list'
[FilterMode]$YARAFilesFilterMode = Get-GHActionsInput -Name 'yara_filesfilter_mode' -Require -Trim
[string[]]$YARARulesFilterList = Get-GHActionsInputFilterList -Name 'yara_rulesfilter_list'
[FilterMode]$YARARulesFilterMode = Get-GHActionsInput -Name 'yara_rulesfilter_mode' -Require -Trim
[bool]$YARAWarning = [bool]::Parse((Get-GHActionsInput -Name 'yara_warning' -Require -Trim))
[pscustomobject[]]$YARARulesFinal = $YARARulesIndex | Where-Object -FilterScript {
	Test-InputFilter -Target $_.Name -FilterList $YARARulesFilterList -FilterMode $YARARulesFilterMode
} | Sort-Object -Property 'Name'
Write-OptimizePSList -InputObject ([ordered]@{
	Targets_List = $LocalTarget ? '{Local}' : ($NetworkTargets -join ',')
	Targets_Count = $LocalTarget ? 1 : ($NetworkTargets.Count)
	Deep = $Deep
	Git_ReverseSession = $GitReverseSession
	ClamAV_Enable = $ClamAVEnable
	ClamAV_Files_Filter_List = $ClamAVFilesFilterList -join ', '
	ClamAV_Files_Filter_Count = $ClamAVFilesFilterList.Count
	ClamAV_Files_Filter_Mode = $ClamAVFilesFilterMode
	ClamAV_MultiScan = $ClamAVMultiScan
	YARA_Enable = $YARAEnable
	YARA_Files_Filter_List = $YARAFilesFilterList -join ', '
	YARA_Files_Filter_Count = $YARAFilesFilterList.Count
	YARA_Files_Filter_Mode = $YARAFilesFilterMode
	YARA_Rules_All_List = $YARARulesIndex.Name -join ', '
	YARA_Rules_All_Count = $YARARulesIndex.Count
	YARA_Rules_Filter_List = $YARARulesFilterList -join ', '
	YARA_Rules_Filter_Count = $YARARulesFilterList.Count
	YARA_Rules_Filter_Mode = $YARARulesFilterMode
	YARA_Rules_Final_List = $YARARulesFinal.Name -join ', '
	YARA_Rules_Final_Count = $YARARulesFinal.Count
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
function Invoke-ScanVirusSession {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Session
	)
	Write-Host -Object "Begin of session `"$Session`"."
	[pscustomobject[]]$ElementsRaw = Get-ChildItem -Path $env:GITHUB_WORKSPACE -Recurse -Force
	[pscustomobject[]]$Elements = $ElementsRaw | Sort-Object
	[string[]]$ElementsListClamAV = @()
	[string[]]$ElementsListYARA = @()
	[pscustomobject[]]$ElementsListDisplay = @()
	$Elements | ForEach-Object {
		[bool]$ElementIsDirectory = Test-Path -Path $_.FullName -PathType Container
		[string]$ElementName = $_.FullName -replace "$([regex]::Escape($env:GITHUB_WORKSPACE))\/", ''
		[UInt64]$ElementSizes = $_.Length
		[hashtable]$ElementListDisplay = @{
			Element = $ElementName
			Flags = @(
				$ElementIsDirectory ? 'D' : ''
			)
		}
		if ($ElementIsDirectory -eq $false) {
			$ElementListDisplay.Sizes = $ElementSizes
			$script:TotalSizesAll += $ElementSizes
		}
		if (
			($LocalTarget -eq $false) -or
			(Test-InputFilter -Target $ElementName -FilterList $ClamAVFilesFilterList -FilterMode $ClamAVFilesFilterMode)
		) {
			$ElementsListClamAV += $_.FullName
			$ElementListDisplay.Flags += 'C'
			if ($ElementIsDirectory -eq $false) {
				$script:TotalSizesClamAV += $ElementSizes
			}
		}
		if (($ElementIsDirectory -eq $false) -and (
			($LocalTarget -eq $false) -or
			(Test-InputFilter -Target $ElementName -FilterList $YARAFilesFilterList -FilterMode $YARAFilesFilterMode)
		)) {
			$ElementsListYARA += $_.FullName
			$ElementListDisplay.Flags += 'Y'
			$script:TotalSizesYARA += $ElementSizes
		}
		$ElementListDisplay.Flags = ($ElementListDisplay.Flags | Sort-Object) -join ''
		$ElementsListDisplay += [pscustomobject]$ElementListDisplay
	}
	$script:TotalElementsAll += $Elements.Count
	$script:TotalElementsClamAV += $ElementsListClamAV.Count
	$script:TotalElementsYARA += $ElementsListYARA.Count
	Enter-GHActionsLogGroup -Title "Elements ($Session) - $($Elements.Count):"
	Write-OptimizePSTable -InputObject ($ElementsListDisplay | Format-Table -Property @('Element', 'Flags', @{Expression = 'Sizes'; Alignment = 'Right'}) -AutoSize -Wrap | Out-String)
	Exit-GHActionsLogGroup
	if ($ClamAVEnable -and ($ElementsListClamAV.Count -gt 0)) {
		[string]$ElementsListClamAVPath = (New-TemporaryFile).FullName
		Set-Content -Path $ElementsListClamAVPath -Value ($ElementsListClamAV -join "`n") -NoNewline -Encoding UTF8NoBOM
		Enter-GHActionsLogGroup -Title "ClamAV result ($Session):"
		[string[]]$ClamAVOutput = Invoke-Expression -Command "clamdscan --fdpass --file-list `"$ElementsListClamAVPath`"$($ClamAVMultiScan ? ' --multiscan' : '')"
		[string[]]$ClamAVResultRaw = @()
		$ClamAVOutput | ForEach-Object -Process {
			if ($_ -notmatch ': OK$') {
				$ClamAVResultRaw += $_ -replace "$([regex]::Escape($env:GITHUB_WORKSPACE))\/", ''
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
	if ($YARAEnable -and ($ElementsListYARA.Count -gt 0)) {
		[string]$ElementsListYARAPath = (New-TemporaryFile).FullName
		Set-Content -Path $ElementsListYARAPath -Value ($ElementsListYARA -join "`n") -NoNewline -Encoding UTF8NoBOM
		[hashtable]$YARAResultRaw = @{}
		Enter-GHActionsLogGroup -Title "YARA result ($Session):"
		foreach ($YARARule in $YARARulesFinal) {
			[string[]]$YARAOutput = Invoke-Expression -Command "yara --scan-list$($YARAWarning ? ' --no-warnings ' : ' ')`"$(Join-Path -Path $YARARulesRoot -ChildPath $YARARule.Entrypoint)`" `"$ElementsListYARAPath`""
			$YARAOutput | ForEach-Object -Process {
				if ($_ -match "^.+? $([regex]::Escape($env:GITHUB_WORKSPACE))\/.+$") {
					Write-GHActionsDebug -Message "$($YARARule.Name)/$_"
					[string]$Rule, [string]$Element = $_ -split '(?<=^.+?) '
					[string]$YARARuleName = "$($YARARule.Name)/$Rule"
					if (($YARARulesFilterMode.GetHashCode() -eq 0) -and (Test-InputFilter -Target "$YARARuleName>$Element" -FilterList $YARARulesFilterList -FilterMode $YARARulesFilterMode)) {
						Write-GHActionsDebug -Message '  > Skip'
					} else {
						$Element = $Element -replace "$([regex]::Escape($env:GITHUB_WORKSPACE))\/", ''
						if ($null -eq $YARAResultRaw[$Element]) {
							$YARAResultRaw[$Element] = @()
						}
						$YARAResultRaw[$Element] += $YARARuleName
					}
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
				$YARAResult[$_.Name] = ($_.Value | Sort-Object) -join ', '
			}
			Write-OptimizePSList -InputObject ($YARAResult.GetEnumerator() | Sort-Object -Property 'Name' | Format-List -Property 'Value' -GroupBy 'Name' | Out-String)
			Write-GHActionsError -Message "Found issues in session `"$Session`" via YARA!"
			$script:ConclusionSetFail = $true
		}
		Exit-GHActionsLogGroup
		Remove-Item -Path $ElementsListYARAPath -Force -Confirm:$false
	}
	Write-Host -Object "End of session $Session."
}
if ($LocalTarget) {
	Invoke-ScanVirusSession -Session 'Current'
	if ($Deep) {
		if (Test-Path -Path '.\.git') {
			Write-Host -Object 'Import Git information.'
			[string[]]$GitCommits = Invoke-Expression -Command "git --no-pager log --all --format=%H --reflog$($GitReverseSession ? '' : ' --reverse')"
			if ($GitCommits.Count -le 1) {
				Write-GHActionsWarning -Message "Current Git repository has only $($GitCommits.Count) commits! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow. (IMPORTANT: ``Re-run all jobs`` or ``Re-run this workflow`` cannot apply the modified workflow!)"
			}
			for ($GitCommitsIndex = 0; $GitCommitsIndex -lt $GitCommits.Count; $GitCommitsIndex++) {
				[string]$GitCommit = $GitCommits[$GitCommitsIndex]
				[string]$GitSession = "Commit #$($GitReverseSession ? ($GitCommits.Count - $GitCommitsIndex) : ($GitCommitsIndex + 1))/$($GitCommits.Count) - $GitCommit"
				Enter-GHActionsLogGroup -Title "Git checkout for session `"$GitSession`"."
				try {
					Invoke-Expression -Command "git checkout $GitCommit --force --quiet"
				} catch {  }
				if ($LASTEXITCODE -eq 0) {
					Exit-GHActionsLogGroup
					Invoke-ScanVirusSession -Session $GitSession
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
		Invoke-ScanVirusSession -Session $_
		Remove-Item -Path $NetworkTemporaryFileFullPath -Force -Confirm:$false
	}
}
Enter-GHActionsLogGroup -Title "Statistics:"
Write-OptimizePSTable -InputObject ([pscustomobject[]]@(
	[pscustomobject]@{
		Name = 'TotalElements_Count'
		All = $TotalElementsAll
		ClamAV = $TotalElementsClamAV
		YARA = $TotalElementsYARA
	},
	[pscustomobject]@{
		Name = 'TotalElements_Percentage'
		All = $null
		ClamAV = $TotalElementsClamAV / $TotalElementsAll * 100
		YARA = $TotalElementsYARA / $TotalElementsAll * 100
	},
	[pscustomobject]@{
		Name = 'TotalSizes_B'
		All = $TotalSizesAll
		ClamAV = $TotalSizesClamAV
		YARA = $TotalSizesYARA
	},
	[pscustomobject]@{
		Name = 'TotalSizes_KB'
		All = $TotalSizesAll / 1KB
		ClamAV = $TotalSizesClamAV / 1KB
		YARA = $TotalSizesYARA / 1KB
	},
	[pscustomobject]@{
		Name = 'TotalSizes_MB'
		All = $TotalSizesAll / 1MB
		ClamAV = $TotalSizesClamAV / 1MB
		YARA = $TotalSizesYARA / 1MB
	},
	[pscustomobject]@{
		Name = 'TotalSizes_GB'
		All = $TotalSizesAll / 1GB
		ClamAV = $TotalSizesClamAV / 1GB
		YARA = $TotalSizesYARA / 1GB
	},
	[pscustomobject]@{
		Name = 'TotalSizes_TB'
		All = $TotalSizesAll / 1TB
		ClamAV = $TotalSizesClamAV / 1TB
		YARA = $TotalSizesYARA / 1TB
	},
	[pscustomobject]@{
		Name = 'TotalSizes_Percentage'
		All = $null
		ClamAV = $TotalSizesClamAV / $TotalSizesAll * 100
		YARA = $TotalSizesYARA / $TotalSizesAll * 100
	}
) | Format-Table -Property @(
	'Name',
	@{Expression = 'All'; Alignment = 'Right'},
	@{Expression = 'ClamAV'; Alignment = 'Right'},
	@{Expression = 'YARA'; Alignment = 'Right'}
) -AutoSize -Wrap | Out-String)
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
