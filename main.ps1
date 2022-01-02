Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
function Get-InputList {
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Name
	)
	[string]$Value = Get-GHActionsInput -Name $Name -Require -Trim
	switch ($Value) {
		{($_ -eq '0') -or ($_ -eq 'none')} { return 0 }
		{($_ -eq '1') -or ($_ -eq 'debug')} { return 1 }
		{($_ -eq '2') -or ($_ -eq 'log')} { return 2 }
	}
	Write-GHActionsFail -Message "Input ``$Name``'s value is not in the list!"
}
function Write-TriageLog {
	param (
		[Parameter(Mandatory = $true, Position = 0)][uint]$Condition,
		[Parameter(Mandatory = $true, Position = 1)][AllowEmptyString()][string]$Message
	)
	if ($Message.Length -gt 0) {
		switch ($Condition) {
			1 { Write-GHActionsDebug -Message $Message; break }
			2 { Write-Host -Object $Message; break }
		}
	}
}
Write-Host -Object 'Import inputs.'
[string]$Integrate = Get-GHActionsInput -Name 'integrate' -Require -Trim
switch ($Integrate) {
	'git' { $Integrate = 'git'; break }
	'none' { $Integrate = 'none'; break }
	{ $Integrate -match '^npm:(?:@[\da-z*~-][\da-z*._~-]*\/)?[\da-z~-][\da-z._~-]*$' } { break }
	Default { Write-GHActionsFail -Message "Input ``integrate``'s value is not in the list!" }
}
[uint]$ListElements = Get-InputList -Name 'list_elements'
[bool]$ListElementsHashes = [bool]::Parse((Get-GHActionsInput -Name 'list_elementshashes' -Require -Trim))
[uint]$ListMiscellaneousResults = Get-InputList -Name 'list_miscellaneousresults'
[uint]$ListScanResults = Get-InputList -Name 'list_scanresults'
Enter-GHActionsLogGroup -Title 'Update ClamAV via FreshClam.'
$FreshClamResult = $null
try {
	$FreshClamResult = $(freshclam) -join "`n"
} catch {
	Write-GHActionsFail -Message 'Unable to execute FreshClam!'
}
if ($LASTEXITCODE -ne 0) {
	[string]$FreshClamError = "$LASTEXITCODE"
	switch ($FreshClamErrorCode) {
		40 { $FreshClamError += ': Unknown option passed'; break }
		50 { $FreshClamError += ': Cannot change directory'; break }
		51 { $FreshClamError += ': Cannot check MD5 sum'; break }
		52 { $FreshClamError += ': Connection (network) problem'; break }
		53 { $FreshClamError += ': Cannot unlink file'; break }
		54 { $FreshClamError += ': MD5 or digital signature verification error'; break }
		55 { $FreshClamError += ': Error reading file'; break }
		56 { $FreshClamError += ': Config file error'; break }
		57 { $FreshClamError += ': Cannot create new file'; break }
		58 { $FreshClamError += ': Cannot read database from remote server'; break }
		59 { $FreshClamError += ': Mirrors are not fully synchronized (try again later)'; break }
		60 { $FreshClamError += ': Cannot get information about user from /etc/passwd'; break }
		61 { $FreshClamError += ': Cannot drop privileges'; break }
		62 { $FreshClamError += ': Cannot initialize logger'; break }
	}
	Write-GHActionsFail -Message "Unexpected FreshClam result: $FreshClamError!`n$FreshClamResult"
}
Write-TriageLog -Condition $ListMiscellaneousResults -Message $FreshClamResult
Exit-GHActionsLogGroup
Enter-GHActionsLogGroup -Title 'Start ClamAV daemon.'
$ClamDStartResult = $null
try {
	$ClamDStartResult = $(clamd) -join "`n"
}
catch {
	Write-GHActionsFail -Message 'Unable to execute ClamD!'
}
if ($LASTEXITCODE -ne 0) {
	Write-GHActionsFail -Message "Unexpected ClamD result: $LASTEXITCODE!`n$ClamDStartResult"
}
Write-TriageLog -Condition $ListMiscellaneousResults -Message $ClamDStartResult
Exit-GHActionsLogGroup
[bool]$ConclusionFail = $false
[string]$ElementsScanListPath = (New-TemporaryFile).FullName
[uint]$TotalScanElements = 0
function Invoke-ScanVirus {
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Session
	)
	Enter-GHActionsLogGroup -Title "Scan $Session."
	[string[]]$Elements = Get-ChildItem -Path $env:GITHUB_WORKSPACE -Recurse -Force -Name
	[uint]$ElementsCount = $Elements.Longlength
	[string]$ElementsListConsole = "Elements ($Session): $ElementsCount`n----------------"
	[string]$ElementsListScan = ''
	foreach ($Element in ($Elements | Sort-Object)) {
		$ElementsListConsole += "`n- $Element"
		$ElementsListScan += "$(Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $Element)`n"
		if ($ListElementsHashes -and (Test-Path -Path $Element -PathType Leaf)) {
			foreach ($Algorithm in @('MD5', 'SHA1', 'SHA256', 'SHA384', 'SHA512')) {
				$ElementsListConsole += "`n  - $($Algorithm): $((Get-FileHash -Path $Element -Algorithm $Algorithm).Hash)"
			}
		}
	}
	Write-TriageLog -Condition $ListElements -Message $ElementsListConsole
	if ($ListElements -gt 0) {
		Write-Host -Object ''
	}
	Set-Content -Path $ElementsScanListPath -Value $ElementsListScan.Trim() -NoNewline -Encoding utf8NoBOM
	$script:TotalScanElements += $ElementsCount
	$ClamDScanResult = $null
	try {
		$ClamDScanResult = $(clamdscan --fdpass --file-list $ElementsScanListPath --multiscan) -join "`n"
	} catch {
		Write-GHActionsFail -Message "Unable to execute ClamDScan ($Session)!"
	}
	if ($LASTEXITCODE -eq 0) {
		Write-TriageLog -Condition $ListScanResults -Message "ClamDScan Result ($Session)`n----------------`n$ClamDScanResult"
	} else {
		[uint]$ClamDScanErrorCode = $LASTEXITCODE
		$script:ConclusionFail = $true
		if ($ClamDScanErrorCode -eq 1) {
			Write-GHActionsError -Message "Found virus in $Session via ClamAV!`n$ClamDScanResult"
		} else {
			Write-GHActionsError -Message "Unexpected ClamDScan result ($Session): $ClamDScanErrorCode!`n$ClamDScanResult"
		}
	}
	<#
	$YARAResult = $null
	try {
		$YARAResult = $(yara --compiled-rules $YARARulesPath --recursive ./) -join "`n"
	} catch {
		Write-GHActionsFail -Message "Unable to execute YARA ($Session)!"
	}
	if ($LASTEXITCODE -eq 0) {
		Write-TriageLog -Condition $ListScanResults -Message "YARA Result ($Session)`n----------------`n$YARAResult"
	} else {
		[uint]$YARAErrorCode = $LASTEXITCODE
		$script:ConclusionFail = $true
		if ($YARAErrorCode -eq 1) {
			Write-GHActionsError -Message "Found virus in $Session via YARA!`n$YARAResult"
		} else {
			Write-GHActionsError -Message "Unexpected YARA result ($Session): $YARAErrorCode!`n$YARAResult"
		}
	}
	#>
	Exit-GHActionsLogGroup
}
if ($Integrate -match '^npm:') {
	Write-Host -Object 'Import NPM information.'
	[string[]]$UselessElements = Get-ChildItem -Path $env:GITHUB_WORKSPACE -Recurse -Force -Name
	if ($UselessElements.Count -gt 0) {
		Write-GHActionsWarning -Message 'NPM integration require a clean workspace!'
		Write-Host -Object 'Clean workspace.'
		$UselessElements | ForEach-Object -Process {
			return Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $_
		} | Remove-Item -Force -Confirm:$false
	}
	[string]$NPMPackageName = $Integrate -replace '^npm:', ''
	[string]$NPMPackageNameSafe = $NPMPackageName -replace '^@', '' -replace '\/', '-'
	Write-TriageLog -Condition $ListMiscellaneousResults -Message "NPM Package: $NPMPackageName"
	$NPMRegistryResponse = $null
	try {
		$NPMRegistryResponse = Invoke-WebRequest -Uri "https://registry.npmjs.org/$NPMPackageName" -UseBasicParsing -Method Get
	} catch {
		Write-GHActionsFail -Message "NPM package `"$PackageName`" not found!`n$($_.Exception.Message)"
	}
	[pscustomobject]$NPMPackageContent = ($NPMRegistryResponse.Content | ConvertFrom-Json -ErrorAction Stop)
	[string[]]$NPMPackageVersionsList = @()
	[hashtable]$NPMPackageVersionsTarballs = [ordered]@{}
	$NPMPackageContent.versions.PSObject.Properties | ForEach-Object -Process {
		$NPMPackageVersionsList += $_.Name
		$NPMPackageVersionsTarballs[$_.Name] = $_.Value.dist.tarball
	}
	[uint]$NPMPackageVersionsCount = $NPMPackageVersionsList.LongLength
	for ($NPMPackageVersionsIndex = 0; $NPMPackageVersionsIndex -lt $NPMPackageVersionsCount; $NPMPackageVersionsIndex++) {
		[string]$NPMPackageCurrentVersion = $NPMPackageVersionsList[$NPMPackageVersionsIndex]
		[string]$NPMPackageCurrentSession = "version #$($NPMPackageVersionsIndex + 1)/$($NPMPackageVersionsCount) ($NPMPackageCurrentVersion)"
		[string]$NPMPackageCurrentTarball = "$NPMPackageNameSafe-$NPMPackageCurrentVersion.tgz"
		[string]$NPMPackageCurrentTarballPath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $NPMPackageCurrentTarball
		Write-Host -Object "Import $NPMPackageCurrentSession."
		try {
			Invoke-WebRequest -Uri "$($NPMPackageVersionsTarballs[$NPMPackageCurrentVersion])" -UseBasicParsing -Method Get -OutFile $NPMPackageCurrentTarballPath
		} catch {
			Write-GHActionsError -Message "Unable to import $NPMPackageCurrentSession!"
			continue
		}
		Invoke-ScanVirus -Session $NPMPackageCurrentSession
		Remove-Item -Path $NPMPackageCurrentTarballPath -Force -Confirm:$false
	}
} else {
	Invoke-ScanVirus -Session 'current workspace'
	if ($Integrate -eq 'git') {
		Write-Host -Object 'Import Git information.'
		if (Test-Path -Path '.\.git') {
			$GitLogResult = $null
			try {
				$GitLogResult = $(git --no-pager log --all --format=%H --reflog --reverse) -join "`n"
			} catch {
				Write-GHActionsFail -Message 'Unable to execute Git-Log!'
			}
			if ($LASTEXITCODE -eq 0) {
				[string[]]$GitCommitsHashes = $GitLogResult -split "`n"
				[uint]$GitCommitsCount = $GitCommitsHashes.Longlength
				if ($GitCommitsCount -le 1) {
					Write-GHActionsWarning -Message "Current Git repository has only $GitCommitsCount commits! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow. (IMPORTANT: ``Re-run all jobs`` or ``Re-run this workflow`` cannot apply the modified workflow!)"
				}
				for ($GitCommitsIndex = 0; $GitCommitsIndex -lt $GitCommitsCount; $GitCommitsIndex++) {
					[string]$GitCommitHash = $GitCommitsHashes[$GitCommitsIndex]
					[string]$GitCurrentSession = "commit #$($GitCommitsIndex + 1)/$($GitCommitsCount) ($GitCommitHash)"
					Write-Host -Object "Checkout $GitCurrentSession."
					$GitCheckoutResult = $null
					try {
						$GitCheckoutResult = $(git checkout "$GitCommitHash" --force --quiet) -join "`n"
					} catch {
						Write-GHActionsFail -Message "Unable to execute Git-Checkout ($GitCurrentSession)!"
					}
					if ($LASTEXITCODE -eq 0) {
						Invoke-ScanVirus -Session $GitCurrentSession
					} else {
						Write-GHActionsError -Message "Unexpected Git-Checkout result ($GitCurrentSession): $LASTEXITCODE!`n$GitCheckoutResult"
					}
				}
			} else {
				Write-GHActionsError -Message "Unexpected Git-Log result: $LASTEXITCODE!`n$GitCommitsRaw"
			}
		} else {
			Write-GHActionsWarning -Message 'Current workspace is not a Git repository!'
		}
	}
}
Write-TriageLog -Condition $ListMiscellaneousResults -Message "Total scan elements: $TotalScanElements"
Remove-Item -Path $ElementsScanListPath -Force -Confirm:$false
Write-Host -Object 'Stop ClamAV daemon.'
Get-Process -Name '*clamd*' | Stop-Process
if ($ConclusionFail) {
	exit 1
}
exit 0
