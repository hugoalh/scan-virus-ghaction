#Requires -PSEdition Core
#Requires -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Function Get-WareMeta {
	[CmdletBinding()]
	Param ()
	Write-Host -Object "$($PSStyle.Bold)System [Debian View]:$($PSStyle.BoldOff)"
	uname --all
	Write-Host -Object "$($PSStyle.Bold)System [PowerShell View]:$($PSStyle.BoldOff)"
	[PSCustomObject]@{
		Platform = $PSVersionTable.Platform
		Version = $PSVersionTable.OS
	} |
		Format-List
	Write-Host -Object "$($PSStyle.Bold)PowerShell (pwsh):$($PSStyle.BoldOff)"
	[PSCustomObject]@{
		Path = Get-Command -Name 'pwsh' -CommandType 'Application' |
			Select-Object -ExpandProperty 'Source'
		Edition = $PSVersionTable.PSEdition
		Version = $PSVersionTable.PSVersion
		CompatibleVersions = $PSVersionTable.PSCompatibleVersions
		RemotingProtocolVersion = $PSVersionTable.PSRemotingProtocolVersion
		SerializationVersion = $PSVersionTable.SerializationVersion
		WSManStackVersion = $PSVersionTable.WSManStackVersion
	} |
		Format-List
	([Ordered]@{
		clamdscan = 'ClamAV Scan Daemon'
		clamscan = 'ClamAV Scan'
		freshclam = 'ClamAV Updater'
		git = 'Git'
		node = 'NodeJS'
		yara = 'YARA'
	}).GetEnumerator() |
		ForEach-Object -Process {
			Write-Host -Object "$($PSStyle.Bold)$($_.Value) ($($_.Name)):$($PSStyle.BoldOff)"
			[PSCustomObject]@{
				Path = Get-Command -Name $_.Name -CommandType 'Application' |
					Select-Object -ExpandProperty 'Source'
			} |
				Format-List
			Invoke-Expression -Command "$($_.Name) --version"
		}
}
Export-ModuleMember -Function @(
	'Get-WareMeta'
)
