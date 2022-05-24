function Test-StringIsURL {
	[CmdletBinding()][OutputType([bool])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$InputObject
	)
	try {
		$URIObject = $InputObject -as [System.URI]
		return (($null -ne $URIObject.AbsoluteURI) -and ($InputObject -match '^https?:\/\/'))
	} catch {
		return $false
	}
}
Export-ModuleMember -Function 'Test-StringIsURL'
