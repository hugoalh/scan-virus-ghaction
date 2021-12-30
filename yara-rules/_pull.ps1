[string]$YaraRulesIndexDelimiter = "`t"
[string[]]$YaraRulesIndexFile = Get-Content -Encoding utf8NoBOM -Path .\yara-rules\_index.tsv
[hashtable]$YaraRulesPullList = @{}
(ConvertFrom-Csv -Delimiter $YaraRulesIndexDelimiter -Header ($YaraRulesIndexFile[0] -split $YaraRulesIndexDelimiter) -InputObject $YaraRulesIndexFile[1..$YaraRulesIndexFile.Count]).PSObject.Properties | ForEach-Object -Process {
	[string]$RemoteRepositoryArchive = "$($_.remote_repository)/archive/$($_.remote_commit)"
	if ($YaraRulesPullList.Contains($RemoteRepositoryArchive) -eq $false) {
		$YaraRulesPullList[$RemoteRepositoryArchive] = @{}
	}
	$YaraRulesPullList[$RemoteRepositoryArchive][$_.remote_path] = $_.local
}
foreach ($RemoteRepositoryArchive in $YaraRulesPullList.Keys) {
	[string]$ArchivePath = "$env:TEMP\$($RemoteRepositoryArchive -replace '[\/.:]', '-')"
	try {
		Invoke-WebRequest -Method Get -OutFile "$ArchivePath.zip" -Uri "$RemoteRepositoryArchive.zip" -UseBasicParsing
	} catch {
		Write-Error -Message "Cannot fetch $RemoteRepositoryArchive!"
		continue
	}
	Expand-Archive -Path "$ArchivePath.zip" -DestinationPath $ArchivePath
	Remove-Item -Force -Path "$ArchivePath.zip"
	[string]$AdditionalFolder = Get-ChildItem -Name -Path $ArchivePath
	$YaraRulesPullList[$RemoteRepositoryArchive].GetEnumerator() | ForEach-Object -Process {
		Copy-Item -Path (Join-Path -Path $ArchivePath -ChildPath $AdditionalFolder -AdditionalChildPath $_.Name) -Destination "yara-rules\$($_.Value)"
	}
	Get-ChildItem -Force -Path $ArchivePath -Recurse | Remove-Item -Force
}
