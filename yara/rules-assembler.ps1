[string]$RulesDirectory = '.\opt\hugoalh\scan-virus-ghaction\yara\rules'
[hashtable]$RulesList = @{}
[string]$IndexDelimiter = "`t"
[string[]]$IndexFile = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath '.\index.tsv') -Encoding 'utf8NoBOM'
ConvertFrom-Csv -InputObject $IndexFile[1..$IndexFile.Count] -Delimiter $IndexDelimiter -Header ($IndexFile[0] -split $IndexDelimiter) | ForEach-Object -Process {
	[string]$RemoteRepositoryArchive = "$($_.remote_repository)/archive/$($_.remote_commit)"
	if ($RulesList.Contains($RemoteRepositoryArchive) -eq $false) {
		$RulesList[$RemoteRepositoryArchive] = @{}
	}
	$RulesList[$RemoteRepositoryArchive][$_.remote_path] = $_.local
}
foreach ($RemoteRepositoryArchive in $RulesList.Keys) {
	[string]$ArchivePath = ".\tmp\$($RemoteRepositoryArchive -replace '[\/.:]+', '-')"
	[string]$ArchiveFile = "$ArchivePath.zip"
	try {
		Invoke-WebRequest -Method Get -Uri "$RemoteRepositoryArchive.zip" -OutFile $ArchiveFile -Verbose
	} catch {
		Write-Error -Message "Cannot fetch `"$RemoteRepositoryArchive.zip`"!"
		continue
	}
	Expand-Archive -Path $ArchiveFile -DestinationPath $ArchivePath
	Remove-Item -Path $ArchiveFile
	[string]$ArchiveAdditionalFolder = Join-Path -Path $ArchivePath -ChildPath (Get-ChildItem -Path $ArchivePath -Name)
	$RulesList[$RemoteRepositoryArchive].GetEnumerator() | ForEach-Object -Process {
		[string]$RuleDestinationPath = Join-Path -Path $RulesDirectory -ChildPath $_.Value
		[string]$RuleDestinationDirectory = Split-Path -Path $RuleDestinationPath -Parent
		if ((Test-Path -Path $RuleDestinationDirectory -PathType Container) -eq $false) {
			New-Item -Path $RuleDestinationDirectory -ItemType Directory
		}
		Copy-Item -Path (Join-Path -Path $ArchiveAdditionalFolder -ChildPath $_.Name) -Destination $RuleDestinationPath
	}
	Get-ChildItem -Path $ArchivePath -Recurse -Force -Name | Remove-Item
}
Get-ChildItem -Path $RulesDirectory -Recurse -Force -Name
