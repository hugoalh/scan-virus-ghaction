[string]$IndexDelimiter = "`t"
[string[]]$IndexFile = Get-Content -Encoding utf8NoBOM -Path "$PSScriptRoot\index.tsv"
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
foreach ($RemoteRepositoryArchive in $RulesPullList.Keys) {
	[string]$ArchivePath = "$env:TEMP\$($RemoteRepositoryArchive -replace '[\/.:]+', '-')"
	try {
		Invoke-WebRequest -Method Get -Uri "$RemoteRepositoryArchive.zip" -UseBasicParsing -OutFile "$ArchivePath.zip"
	} catch {
		Write-Error -Message "Cannot fetch `"$RemoteRepositoryArchive`"!"
		continue
	}
	Expand-Archive -Path "$ArchivePath.zip" -DestinationPath $ArchivePath
	Remove-Item -Path "$ArchivePath.zip" -Force
	[string]$ArchiveAdditionalFolder = Join-Path -Path $ArchivePath -ChildPath (Get-ChildItem -Path $ArchivePath -Name)
	$RulesPullList[$RemoteRepositoryArchive].GetEnumerator() | ForEach-Object -Process {
		Copy-Item -Path (Join-Path -Path $ArchiveAdditionalFolder -ChildPath $_.Name) -Destination "$PSScriptRoot\rules\$($_.Value)"
	}
	Get-ChildItem -Path $ArchivePath -Force -Recurse | Remove-Item -Force
}
Invoke-Expression -Command "yarac $($RulesNameList -join ' ') rules.yarac"
