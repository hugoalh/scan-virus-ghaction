Import-Module -Name "$PSScriptRoot\hugoalh.GitHubActionsToolkit.psm1" -Scope Local
function Get-InputList {
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Name
	)
	$Value = Get-GHActionsInput -Name $Name -Require -Trim
	switch ($Value) {
		{$_ -in @(0, '0', 'none')} { return 0 }
		{$_ -in @(1, '1', 'debug')} { return 1 }
		{$_ -in @(2, '2', 'log')} { return 2 }
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
			1 { Write-GHActionsDebug -Message $Message }
			2 { Write-Host -Object $Message }
		}
	}
}
Write-Host -Object 'Import inputs.'
$Integrate = (Get-GHActionsInput -Name 'integrate' -Require -Trim).ToLower()
if ($Integrate -notin @('none', 'git')) {
	if ($Integrate -notmatch '^npm:(?:@[\da-z*~-][\da-z*._~-]*\/)?[\da-z~-][\da-z._~-]*$') {
		Write-GHActionsFail -Message "Input ``integrate``'s value is not in the list!"
	}
}
$ListElements = Get-InputList -Name 'list_elements'
$ListElementsHashes = [bool]::Parse((Get-GHActionsInput -Name 'list_elementshashes' -Require -Trim))
$ListMiscellaneousResults = Get-InputList -Name 'list_miscellaneousresults'
$ListScanResults = Get-InputList -Name 'list_scanresults'
Enter-GHActionsLogGroup -Title 'Update ClamAV via FreshClam.'
$FreshClamResult = $null
try {
	$FreshClamResult = $(freshclam) -join "`n"
} catch {
	Write-GHActionsFail -Message 'Unable to execute FreshClam!'
}
if ($LASTEXITCODE -ne 0) {
	$FreshClamErrorCode = $LASTEXITCODE
	$FreshClamErrorMessage = ''
	switch ($FreshClamErrorCode) {
		40 { $FreshClamErrorMessage = ': Unknown option passed' }
		50 { $FreshClamErrorMessage = ': Cannot change directory' }
		51 { $FreshClamErrorMessage = ': Cannot check MD5 sum' }
		52 { $FreshClamErrorMessage = ': Connection (network) problem' }
		53 { $FreshClamErrorMessage = ': Cannot unlink file' }
		54 { $FreshClamErrorMessage = ': MD5 or digital signature verification error' }
		55 { $FreshClamErrorMessage = ': Error reading file' }
		56 { $FreshClamErrorMessage = ': Config file error' }
		57 { $FreshClamErrorMessage = ': Cannot create new file' }
		58 { $FreshClamErrorMessage = ': Cannot read database from remote server' }
		59 { $FreshClamErrorMessage = ': Mirrors are not fully synchronized (try again later)' }
		60 { $FreshClamErrorMessage = ': Cannot get information about user from /etc/passwd' }
		61 { $FreshClamErrorMessage = ': Cannot drop privileges' }
		62 { $FreshClamErrorMessage = ': Cannot initialize logger' }
	}
	Write-GHActionsError -Message $FreshClamResult -Title "Unexpected FreshClam result ($($FreshClamErrorCode)$($FreshClamErrorMessage))"
	exit 1
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
	Write-GHActionsError -Message $ClamDStartResult -Title "Unexpected ClamD result ($LASTEXITCODE)"
	exit 1
}
Write-TriageLog -Condition $ListMiscellaneousResults -Message $ClamDStartResult
Exit-GHActionsLogGroup
$ConclusionFail = $false
$ScanElementsList = (New-TemporaryFile).FullName
$TotalScanElements = 0
function Invoke-ScanVirus {
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Session
	)
	Enter-GHActionsLogGroup -Title "Scan $Session."
	$Elements = (Get-ChildItem -Force -Name -Path $env:GITHUB_WORKSPACE -Recurse | Sort-Object)
	$ElementsLength = $Elements.Longlength
	$ListElementsMessage = "Elements ($Session - $ElementsLength):"
	$ElementsRaw = ''
	foreach ($Element in $Elements) {
		$ListElementsMessage += "`n- $Element"
		$ElementsRaw += "$(Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $Element)`n"
		if ($ListElementsHashes -and (Test-Path -Path $Element -PathType Leaf)) {
			foreach ($Algorithm in @('MD5', 'SHA1', 'SHA256', 'SHA384', 'SHA512')) {
				$ListElementsMessage += "`n  - $($Algorithm): $((Get-FileHash -Algorithm $Algorithm -Path $Element).Hash)"
			}
		}
	}
	Write-TriageLog -Condition $ListElements -Message $ListElementsMessage
	Set-Content -Encoding utf8NoBOM -NoNewline -Path $ScanElementsList -Value $ElementsRaw.Trim()
	$script:TotalScanElements += $ElementsLength
	$ClamDScanResult = $null
	try {
		$ClamDScanResult = $(clamdscan --fdpass --file-list $ScanElementsList --multiscan) -join "`n"
	} catch {
		Write-GHActionsFail -Message "Unable to execute ClamDScan ($Session)!"
	}
	if ($LASTEXITCODE -eq 0) {
		Write-TriageLog -Condition $ListScanResults -Message "ClamDScan Result ($Session):`n$ClamDScanResult"
	} else {
		$ClamDScanErrorCode = $LASTEXITCODE
		$script:ConclusionFail = $true
		if ($ClamDScanErrorCode -eq 1) {
			Write-GHActionsError -Message $ClamDScanResult -Title "Found virus in $Session via ClamAV"
		} else {
			Write-GHActionsError -Message $ClamDScanResult -Title "Unexpected ClamDScan result ($Session) ($ClamDScanErrorCode)"
		}
	}
	Exit-GHActionsLogGroup
}
if ($Integrate -match '^npm:') {
	Write-Host -Object 'Import NPM information.'
	$Elements = Get-ChildItem -Force -Name -Path $env:GITHUB_WORKSPACE -Recurse
	if ($Elements.Count -gt 0) {
		Write-GHActionsWarning -Message 'NPM integration require a clean workspace! To not show this message again, please do not use `actions/checkout` in the previous steps.'
		$Elements | Remove-Item -Force
	}
	$NPMPackageName = $Integrate -replace '^npm:', ''
	$NPMPackageNameEncode = $NPMPackageName -replace '^@', '' -replace '\/', '-'
	Write-TriageLog -Condition $ListMiscellaneousResults -Message "NPM Package: $NPMPackageName"
	$NPMRegistryResponse = $null
	try {
		$NPMRegistryResponse = Invoke-WebRequest -Method Get -Uri "https://registry.npmjs.org/$NPMPackageName" -UseBasicParsing
	} catch {
		Write-GHActionsFail -Message "NPM package `"$PackageName`" not found!"
	}
	$NPMPackageContent = $NPMRegistryResponse.Content | ConvertFrom-Json -Depth 100 -ErrorAction Stop
	$NPMPackageVersionsList = @()
	$NPMPackageVersionsTarballs = [ordered]@{}
	$NPMPackageContent.versions.PSObject.Properties | ForEach-Object -Process {
		$NPMPackageVersionsList += $_.Name
		$NPMPackageVersionsTarballs[$_.Name] = $_.Value.dist.tarball
	}
	$NPMPackageVersionsLength = $NPMPackageVersionsList.LongLength
	for ($NPMPackageVersionsIndex = 0; $NPMPackageVersionsIndex -lt $NPMPackageVersionsLength; $NPMPackageVersionsIndex++) {
		$NPMPackageCurrentVersion = $NPMPackageVersionsList[$NPMPackageVersionsIndex]
		$NPMPackageCurrentTarball = "$NPMPackageNameEncode-$NPMPackageCurrentVersion.tgz"
		$NPMPackageCurrentTarballUrl = $NPMPackageVersionsTarballs[$NPMPackageCurrentVersion]
		Write-Host -Object "Import version #$($NPMPackageVersionsIndex + 1)/$($NPMPackageVersionsLength) ($NPMPackageCurrentVersion)."
		try {
			$NPMPackageCurrentTarballOutFilePath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $NPMPackageCurrentTarball
			Invoke-WebRequest -Method Get -OutFile $NPMPackageCurrentTarballOutFilePath -Uri $NPMPackageCurrentTarballUrl -UseBasicParsing
		} catch {
			Write-GHActionsError -Message "Unable to import version #$($NPMPackageVersionsIndex + 1)/$($NPMPackageVersionsLength) ($NPMPackageCurrentVersion)!"
			continue
		}
		Invoke-ScanVirus -Session "version #$($NPMPackageVersionsIndex + 1)/$($NPMPackageVersionsLength) ($NPMPackageCurrentVersion)."
		Remove-Item -Force -Path $(Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $NPMPackageCurrentTarball)
	}
} else {
	Invoke-ScanVirus -Session 'current workspace'
	if ($Integrate -eq 'git') {
		Write-Host -Object 'Import Git information.'
		Write-TriageLog -Condition $ListMiscellaneousResults -Message "Repository: $env:GITHUB_REPOSITORY"
		if (Test-Path -Path .\.git) {
			$GitCommitsRaw = $null
			try {
				$GitCommitsRaw = $(git --no-pager log --all --format=%H --reflog --reverse) -join "`n"
			} catch {
				Write-GHActionsFail -Message 'Unable to execute Git-Log!'
			}
			if ($LASTEXITCODE -eq 0) {
				$GitCommits = $GitCommitsRaw -split "`n"
				$GitCommitsLength = $GitCommits.Longlength
				if ($GitCommitsLength -le 1) {
					Write-GHActionsWarning -Message "Current Git repository has only $GitCommitsLength commits! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow. (IMPORTANT: ``Re-run all jobs`` or ``Re-run this workflow`` cannot apply the modified workflow!)"
				}
				for ($GitCommitsIndex = 0; $GitCommitsIndex -lt $GitCommitsLength; $GitCommitsIndex++) {
					$GitCommit = $GitCommits[$GitCommitsIndex]
					Write-Host -Object "Checkout commit #$($GitCommitsIndex + 1)/$($GitCommitsLength) ($GitCommit)."
					$GitCheckoutResult = $null
					try {
						$GitCheckoutResult = $(git checkout "$GitCommit" --force --quiet) -join "`n"
					} catch {
						Write-GHActionsFail -Message "Unable to execute Git-Checkout (commit #$($GitCommitsIndex + 1)/$($GitCommitsLength) ($GitCommit))!"
					}
					if ($LASTEXITCODE -eq 0) {
						Invoke-ScanVirus -Session "commit #$($GitCommitsIndex + 1)/$($GitCommitsLength) ($GitCommit)"
					} else {
						Write-GHActionsError -Message $GitCheckoutResult -Title "Unexpected Git-Checkout result (commit #$($GitCommitsIndex + 1)/$($GitCommitsLength) ($GitCommit)) ($LASTEXITCODE)"
					}
				}
			} else {
				Write-GHActionLog -Message $GitCommitsRaw
				Write-GHActionsError -Message $GitCommitsRaw -Title "Unexpected Git-Log result ($LASTEXITCODE)"
			}
		} else {
			Write-GHActionsWarning -Message 'Current workspace is not a Git repository!'
		}
	}
}
Write-TriageLog -Condition $ListMiscellaneousResults -Message "Total scan elements: $TotalScanElements"
Remove-Item -Path $ScanElementsList
Write-Host -Object 'Stop ClamAV daemon.'
Get-Process -Name *clamd* | Stop-Process
if ($ConclusionFail) {
	exit 1
}
exit 0
