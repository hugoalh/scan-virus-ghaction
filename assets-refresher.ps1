Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'get-csv.psm1') -Scope 'Local'
function Read-HostChoice {
	[CmdletBinding()][OutputType([bool])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Title,
		[Parameter(Mandatory = $true, Position = 1)][string]$Message
	)
	$OptionYes = New-Object System.Management.Automation.Host.ChoiceDescription @("&Yes", "Description.")
	$OptionNo = New-Object System.Management.Automation.Host.ChoiceDescription @("&No", "Description.")
	$OptionCancel = New-Object System.Management.Automation.Host.ChoiceDescription @("&Cancel", "Description.")
	$Options = [System.Management.Automation.Host.ChoiceDescription[]]($OptionYes, $OptionNo, $OptionCancel)
	$Result = $Host.UI.PromptForChoice($Title, $Message, $Options, 1)
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
	[pscustomobject[]]$AssetIndex = Get-Csv -Path (Join-Path -Path $AssetRoot -ChildPath 'index.tsv') -Delimiter "`t"
	foreach ($Item in $AssetIndex) {
		[string]$OutFileFullName = Join-Path -Path $AssetRoot -ChildPath $Item.Location
		if (
			((Test-Path -Path $OutFileFullName) -eq $false) -or
			(Read-HostChoice -Title 'Update file?' -Message $OutFileFullName)
		) {
			[string]$OutFileRoot = Split-Path -Path $OutFileFullName -Parent
			if ((Test-Path -Path $OutFileRoot) -eq $false) {
				New-Item -Path $OutFileRoot -ItemType 'Directory'
			}
			Invoke-WebRequest -Uri $Item.Source -UseBasicParsing -OutFile $OutFileFullName
			Start-Sleep -Seconds 2
		}
	}
}
