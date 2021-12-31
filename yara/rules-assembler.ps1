[string]$IndexDelimiter = "`t"
[string[]]$IndexFile = Get-Content -Encoding utf8NoBOM -Path .\index.tsv
[string[]]$RulesNameList = @()
[hashtable]$RulesPullList = @{}
ConvertFrom-Csv -Delimiter $IndexDelimiter -Header ($IndexFile[0] -split $IndexDelimiter) -InputObject $IndexFile[1..$IndexFile.Count] | ForEach-Object -Process {
	if ($_.enable -eq 'TRUE') {
		$RulesNameList += "$($_.name):rules/$($_.local)"
		[string]$RemoteRepositoryArchive = "$($_.remote_repository)/archive/$($_.remote_commit)"
		if ($RulesPullList.Contains($RemoteRepositoryArchive) -eq $false) {
			$RulesPullList[$RemoteRepositoryArchive] = @{}
		}
		$RulesPullList[$RemoteRepositoryArchive][$_.remote_path] = $_.local
	}
}
New-Item -ItemType Directory -Path .\ -Name rules
foreach ($RemoteRepositoryArchive in $RulesPullList.Keys) {
	[string]$ArchivePath = ".\rules\$($RemoteRepositoryArchive -replace '[\/.:]+', '-')"
	[string]$ArchiveFile = "$ArchivePath.zip"
	try {
		Invoke-WebRequest -Method Get -Uri "$RemoteRepositoryArchive.zip" -OutFile $ArchiveFile -Verbose
	} catch {
		Write-Error -Message "Cannot fetch `"$RemoteRepositoryArchive.zip`"!"
		continue
	}
	Expand-Archive -Path $ArchiveFile -DestinationPath $ArchivePath
	Remove-Item -Path $ArchiveFile -Force
	[string]$ArchiveAdditionalFolder = Join-Path -Path $ArchivePath -ChildPath (Get-ChildItem -Path $ArchivePath -Name)
	$RulesPullList[$RemoteRepositoryArchive].GetEnumerator() | ForEach-Object -Process {
		Copy-Item -Path (Join-Path -Path $ArchiveAdditionalFolder -ChildPath $_.Name) -Destination ".\rules\$($_.Value)"
	}
	Get-ChildItem -Path $ArchivePath -Force -Recurse | Remove-Item -Force
}
Invoke-Expression -Command "yarac $($RulesNameList -join ' ') rules.yarac"
