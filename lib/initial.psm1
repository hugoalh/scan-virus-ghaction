#Requires -PSEdition Core
#Requires -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Function Get-SoftwareMeta {
	[CmdletBinding()]
	Param ()
	[Ordered]@{
		System_Platform = $PSVersionTable.Platform
		System_Version = $PSVersionTable.OS
		PowerShell_Edition = $PSVersionTable.PSEdition
		PowerShell_Version = $PSVersionTable.PSVersion
		PowerShell_CompatibleVersions = $PSVersionTable.PSCompatibleVersions
		PowerShell_RemotingProtocolVersion = $PSVersionTable.PSRemotingProtocolVersion
		PowerShell_SerializationVersion = $PSVersionTable.SerializationVersion
		PowerShell_WSManStackVersion = $PSVersionTable.WSManStackVersion
	} |
		Format-Table -AutoSize -Wrap
	Get-Command -Name @('clamdscan', 'clamscan', 'freshclam', 'git', 'node', 'pwsh', 'yara') -CommandType 'Application' |
		Format-Table -AutoSize -Wrap -Property @('Name', 'Version', 'Source')
}
Export-ModuleMember -Function @(
	'Get-SoftwareMeta'
)
