function Import-TSV {
	[CmdletBinding()][OutputType([pscustomobject[]])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Path
	)
	[string[]]$Raw = Get-Content -Path $Path -Encoding UTF8NoBOM
	return ConvertFrom-Csv -InputObject $Raw[1..$Raw.Count] -Delimiter "`t" -Header ($Raw[0] -split "`t")
}
function Read-HostChoice {
	[CmdletBinding()][OutputType([bool])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Title,
		[Parameter(Mandatory = $true, Position = 1)][string]$Message
	)
	$OptionYes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Description."
	$OptionNo = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Description."
	$OptionCancel = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel","Description."
	$Options = [System.Management.Automation.Host.ChoiceDescription[]]($OptionYes, $OptionNo, $OptionCancel)
	$Result = $Host.UI.PromptForChoice($Title, $Message, $Options, 0)
	switch ($Result) {
		0 { return $true }
		1 { return $false }
		2 { exit 0 }
	}
}
[string[]]$Assets = @(
	'clamav-signatures-ignore-presets',
	'clamav-unofficial-signatures'
)
foreach ($Asset in $Assets) {
	[string]$AssetRoot = Join-Path -Path $PSScriptRoot -ChildPath $Asset
	[pscustomobject[]]$AssetIndex = Import-TSV -Path (Join-Path -Path $AssetRoot -ChildPath 'index.tsv')
	foreach ($Item in $AssetIndex) {
		[string]$OutFileFullPath = Join-Path -Path $AssetRoot -ChildPath $Item.Location
		if (
			((Test-Path -Path $OutFileFullPath) -eq $false) -or
			(Read-HostChoice -Title 'Update file?' -Message $OutFileFullPath)
		) {
			[string]$OutFileParentDirectory = Split-Path -Path $OutFileFullPath -Parent
			if ((Test-Path -Path $OutFileParentDirectory) -eq $false) {
				New-Item -Path $OutFileParentDirectory -ItemType 'Directory'
			}
			Invoke-WebRequest -Uri $Item.Source -UseBasicParsing -OutFile $OutFileFullPath
			Start-Sleep -Seconds 5
		}
	}
}
