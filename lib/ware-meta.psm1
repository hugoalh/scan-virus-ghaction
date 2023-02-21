#Requires -PSEdition Core
#Requires -Version 7.3
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'display'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'

Function Get-WareMeta {
	[CmdletBinding()]
	Param ()
	Write-Header1 -InputObject 'System'
	hwinfo --all
	Write-Header1 -InputObject 'PowerShell (pwsh)'
	Get-Command -Name 'pwsh' -CommandType 'Application' |
		Format-List -Property '*'
	[PSCustomObject]@{
		System = "$($PSVersionTable.Platform), $($PSVersionTable.OS)"
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
			Write-Header1 -InputObject "$($_.Value) ($($_.Name))"
			Get-Command -Name $_.Name -CommandType 'Application' |
				Format-List -Property '*'
			[PSCustomObject]@{
					VersionStdOut = Invoke-Expression -Command "$($_.Name) --version"
			} |
				Format-List
		}
}
Export-ModuleMember -Function @(
	'Get-WareMeta'
)
