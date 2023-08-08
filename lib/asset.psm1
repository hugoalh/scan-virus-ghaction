#Requires -PSEdition Core -Version 7.2
[String]$BundleUri = 'https://github.com/hugoalh/scan-virus-ghaction-assets/archive/{0}.tar.gz'
[SemVer]$BundleVersion = [SemVer]::Parse('1.0.0')
Function Import-ScanVirusUnofficialAsset {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Position = 0)][AllowEmptyString()][String]$Version,
		[Switch]$Setup
	)
	[String]$VersionResolve = ($Version.Length -gt 0) ? $Version : $BundleVersion.ToString()
	Switch -RegEx ($VersionResolve) {
		'^main$' {
			[String]$BundleUriResolve = $BundleUri -f 'refs/heads/main'
			[String]$SubPathSuffix = 'main'
		}
		'^v?(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$' {
			[String]$BundleUriResolve = $BundleUri -f "refs/tags/v$($VersionResolve -ireplace '^v', '')"
			[String]$SubPathSuffix = $VersionResolve -ireplace '^v', ''
		}
		'^[\da-f]{40}$' {
			[String]$BundleUriResolve = $BundleUri -f $VersionResolve.ToLower()
			[String]$SubPathSuffix = $VersionResolve.ToLower()
		}
		Default {
			Throw "``$VersionResolve`` is not a valid Git tree-ish!"
		}
	}
	[String]$OutDir = "/tmp/$([System.IO.Path]::GetRandomFileName())"
	[String]$OutFile = "$OutDir.tar.gz"
	[String]$SubPath = "scan-virus-ghaction-assets-$SubPathSuffix"
	$Null = Invoke-WebRequest -Uri $BundleUriResolve -MaximumRetryCount 5 -RetryIntervalSec 5 -Method 'Get' -OutFile $OutFile
	$Null = New-Item -Path $OutDir -ItemType 'Directory' -Confirm:$False
	$Null = tar "--directory=$OutDir" --extract "--file=$OutFile" --gzip
	If (!$Setup.IsPresent) {
		[PSCustomObject]$MetaDataLocal = Get-Content -LiteralPath (Join-Path -Path $Env:GHACTION_SCANVIRUS_PROGRAM_ASSET -ChildPath 'metadata.json') |
			ConvertFrom-Json -Depth 100
		[PSCustomObject]$MetaDataRemote = Get-Content -LiteralPath (Join-Path -Path $OutDir -ChildPath $SubPath -AdditionalChildPath @('metadata.json')) |
			ConvertFrom-Json -Depth 100
		If ($MetaDataLocal.format -ne $MetaDataRemote.format) {
			Throw 'Store format are not match!'
		}
		Get-ChildItem -LiteralPath $Env:GHACTION_SCANVIRUS_PROGRAM_ASSET |
			ForEach-Object -Process {
				Remove-Item -LiteralPath $_.FullName -Recurse -Confirm:$False
			}
	}
	Copy-Item -Path (Join-Path -Path $OutDir -ChildPath $SubPath) -Destination $Env:GHACTION_SCANVIRUS_PROGRAM_ASSET
}
Export-ModuleMember -Function @(
	'Import-ScanVirusUnofficialAsset'
)
