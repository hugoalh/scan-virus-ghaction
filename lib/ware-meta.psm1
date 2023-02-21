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
	Write-Header2 -InputObject 'System: '
	hwinfo --all
	Write-Header2 -InputObject 'PowerShell (pwsh): '
	[PSCustomObject]@{
		Path = Get-Command -Name 'pwsh' -CommandType 'Application' |
			Select-Object -ExpandProperty 'Source'
		System = "$($PSVersionTable.Platform), $($PSVersionTable.OS)"
		Edition = $PSVersionTable.PSEdition
		Version = $PSVersionTable.PSVersion
		CompatibleVersions = $PSVersionTable.PSCompatibleVersions
		RemotingProtocolVersion = $PSVersionTable.PSRemotingProtocolVersion
		SerializationVersion = $PSVersionTable.SerializationVersion
		WSManStackVersion = $PSVersionTable.WSManStackVersion
	} |
		Format-List |
		Out-String |
		Write-Display
	([Ordered]@{
		clamdscan = 'ClamAV Scan Daemon'
		clamscan = 'ClamAV Scan'
		freshclam = 'ClamAV Updater'
		git = 'Git'
		node = 'NodeJS'
		yara = 'YARA'
	}).GetEnumerator() |
		ForEach-Object -Process {
			Write-Header2 -InputObject "$($_.Value) ($($_.Name)): "
			[PSCustomObject]@{
				Path = Get-Command -Name $_.Name -CommandType 'Application' |
					Select-Object -ExpandProperty 'Source'
				StdOut = Invoke-Expression -Command "$($_.Name) --version"
			} |
				Format-List |
				Out-String |
				Write-Display
		}
}
Export-ModuleMember -Function @(
	'Get-WareMeta'
)
