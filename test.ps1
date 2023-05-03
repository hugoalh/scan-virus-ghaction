Function Test-ElementIsIgnore {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][PSCustomObject]$Element,
		[Parameter(Mandatory = $True, Position = 1)][AllowEmptyCollection()][Alias('Ignores')][PSCustomObject[]]$Ignore
	)
	ForEach ($IgnoreItem In $Ignore) {
		[String[]]$ElementKeys = $Element.PSObject.Properties.Name
		[String[]]$IgnoreItemKeys = $IgnoreItem.PSObject.Properties.Name
		If ($IgnoreItemKeys.Count -ne $ElementKeys.Count) {
			Continue
		}
		[UInt16]$IgnoreMatchCount = 0
		ForEach ($Property In @('Path', 'Rule', 'Session', 'Signature', 'Tool')) {
			Try {
				If (($ElementKeys -icontains $Property) -and ($IgnoreItemKeys -icontains $Property)) {
					If ($Element.$Property -imatch $IgnoreItem.$Property) {
						$IgnoreMatchCount += 1
					}
				}
			}
			Catch {}
		}
		If ($IgnoreMatchCount -ge $ElementKeys.Count) {
			Write-Output -InputObject $True
		}
	}
	Write-Output -InputObject $False
}
Test-ElementIsIgnore -Element ([PSCustomObject]@{
	Path = 'assets/yara-unofficial/bartblaze/rules/crimeware/ArechClient_Campaign_July2021.yar'
}) -Ignore ([PSCustomObject]@{
	Path = '\.yara?$'
})