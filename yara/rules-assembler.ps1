[string]$RulesDirectory = '.\opt\hugoalh\scan-virus-ghaction\yara\rules'
[hashtable]$RulesList = @{}
[string]$IndexDelimiter = "`t"
[string[]]$IndexFile = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath '.\index.tsv') -Encoding 'utf8NoBOM' -Verbose
ConvertFrom-Csv -InputObject $IndexFile[1..$IndexFile.Count] -Delimiter $IndexDelimiter -Header ($IndexFile[0] -split $IndexDelimiter) -Verbose | ForEach-Object -Process {
	[string]$RemoteRepositoryArchive = "$($_.remote_repository)/archive/$($_.remote_commit)"
	if ($RulesList.Contains($RemoteRepositoryArchive) -eq $false) {
		$RulesList[$RemoteRepositoryArchive] = @{}
	}
	$RulesList[$RemoteRepositoryArchive][$_.remote_path] = $_.local
} -Verbose
foreach ($RemoteRepositoryArchive in $RulesList.Keys) {
	[string]$ArchivePath = ".\tmp\$($RemoteRepositoryArchive -replace '[\/.:]+', '-')"
	[string]$ArchiveFile = "$ArchivePath.zip"
	try {
		Invoke-WebRequest -Uri "$RemoteRepositoryArchive.zip" -UseBasicParsing -Method Get -OutFile $ArchiveFile -Verbose
	} catch {
		Write-Error -Message "Cannot fetch `"$RemoteRepositoryArchive.zip`"!"
		continue
	}
	Expand-Archive -Path $ArchiveFile -DestinationPath $ArchivePath -Verbose
	Remove-Item -Path $ArchiveFile -Force -Confirm:$false -Verbose
	[string]$ArchiveAdditionalFolder = Join-Path -Path $ArchivePath -ChildPath (Get-ChildItem -Path $ArchivePath -Name -Verbose) -Verbose
	$RulesList[$RemoteRepositoryArchive].GetEnumerator() | ForEach-Object -Process {
		[string]$RuleDestinationPath = Join-Path -Path $RulesDirectory -ChildPath $_.Value -Verbose
		[string]$RuleDestinationDirectory = Split-Path -Path $RuleDestinationPath -Parent -Verbose
		if ((Test-Path -Path $RuleDestinationDirectory -PathType Container -Verbose) -eq $false) {
			New-Item -Path $RuleDestinationDirectory -ItemType Directory -Verbose
		}
		Copy-Item -Path (Join-Path -Path $ArchiveAdditionalFolder -ChildPath $_.Name -Verbose) -Destination $RuleDestinationPath -Verbose
	} -Verbose
	Get-ChildItem -Path $ArchivePath -Recurse -Force -Name -Verbose | ForEach-Object -Process {
		return Join-Path -Path $ArchivePath -ChildPath $_
	} -Verbose | Remove-Item -Force -Confirm:$false -Verbose
}
