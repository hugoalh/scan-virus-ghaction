#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'internal',
		'token'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
[Hashtable]$ImportCsvParameters_Tsv = @{
	Delimiter = "`t"
	Encoding = 'UTF8NoBOM'
}
[Hashtable]$InvokeWebRequestParameters_Get = @{
	MaximumRedirection = 1
	MaximumRetryCount = 5
	Method = 'Get'
	RetryIntervalSec = 10
}
[ValidateScript({ Test-Path -LiteralPath $_ -PathType 'Container' })][String]$ClamAVDatabaseRoot = $Env:GHACTION_SCANVIRUS_CLAMAV_DATA
[ValidateScript({ Test-Path -LiteralPath $_ -PathType 'Container' })][String]$ClamAVUnofficialAssetsRoot = $Env:GHACTION_SCANVIRUS_PROGRAM_ASSETS_CLAMAV
[ValidateScript({ Test-Path -LiteralPath $_ -PathType 'Container' })][String]$YaraUnofficialAssetsRoot = $Env:GHACTION_SCANVIRUS_PROGRAM_ASSETS_YARA
[String]$IndexFileName = 'index.tsv'
[String]$ClamAVUnofficialAssetsIndexFilePath = Join-Path -Path $ClamAVUnofficialAssetsRoot -ChildPath $IndexFileName
[String]$YaraUnofficialAssetsIndexFilePath = Join-Path -Path $YaraUnofficialAssetsRoot -ChildPath $IndexFileName
Function Import-NetworkTarget {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Uri]$Target
	)
	Enter-GitHubActionsLogGroup -Title "Fetch file ``$Target``."
	[String]$NetworkTargetFilePath = Join-Path -Path $Env:GITHUB_WORKSPACE -ChildPath "$(New-RandomToken).tmp"
	Try {
		Invoke-WebRequest -Uri $Target -OutFile $NetworkTargetFilePath @InvokeWebRequestParameters_Get
	}
	Catch {
		Write-GitHubActionsError -Message "Unable to fetch file ``$Target``: $_"
		Return
	}
	Finally {
		Exit-GitHubActionsLogGroup
	}
	Write-Output -InputObject $NetworkTargetFilePath
}
Function Register-ClamAVUnofficialAssets {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][AllowEmptyCollection()][Alias('Selections')][RegEx[]]$Selection
	)
	[PSCustomObject[]]$IndexTable = Import-Csv -LiteralPath $ClamAVUnofficialAssetsIndexFilePath @ImportCsvParameters_Tsv |
		Where-Object -FilterScript { $_.Type -ine 'Group' -and $_.Path.Length -gt 0 } |
		ForEach-Object -Process { [PSCustomObject]@{
			Type = $_.Type
			Name = $_.Name
			FilePath = Join-Path -Path $ClamAVUnofficialAssetsRoot -ChildPath $_.Path
			DatabaseFileName = $_.Path -ireplace '\/', '_'
			ApplyIgnores = $_.ApplyIgnores
			Select = Test-StringMatchRegExs -Item $_.Name -Matchers $Selection
		} } |
		Sort-Object -Property @('Type', 'Name')
	[PSCustomObject]@{
		All = $IndexTable.Count
		Select = $IndexTable |
			Where-Object -FilterScript { $_.Select } |
			Measure-Object |
			Select-Object -ExpandProperty 'Count'
	} |
		Format-List -Property '*' |
		Out-String -Width 120 |
		Write-Host
	$IndexTable |
		Format-Table -Property @(
			'Type',
			'Name',
			@{ Expression = 'Select'; Alignment = 'Right' }
		) -AutoSize -Wrap |
		Out-String -Width 120 |
		Write-Host
	[String[]]$AssetsApplyPaths = @()
	[String[]]$AssetsApplyIssues = @()
	ForEach ($IndexApply In (
		$IndexTable |
			Where-Object -FilterScript { $_.Select }
	)) {
		[String]$DestinationFilePath = Join-Path -Path $ClamAVDatabaseRoot -ChildPath $IndexApply.DatabaseFileName
		Try {
			Copy-Item -LiteralPath $IndexApply.FilePath -Destination $DestinationFilePath -Confirm:$False
			$AssetsApplyPaths += $DestinationFilePath
		}
		Catch {
			Write-GitHubActionsError -Message "Unable to apply ClamAV unofficial asset ``$($IndexApply.Name)``: $_"
			$AssetsApplyIssues += $IndexApply.Name
		}
	}
	ForEach ($IndexApply In (
		$IndexTable |
			Where-Object -FilterScript { $_.Select -and $_.ApplyIgnores.Length -gt 0 }
	)) {
		[String[]]$ApplyIgnoresRaw = $IndexApply.ApplyIgnores -isplit ',' |
			ForEach-Object -Process { $_.Trim() } |
			Where-Object -FilterScript { $_.Length -gt 0 }
		ForEach ($ApplyIgnoreRaw In $ApplyIgnoresRaw) {
			[PSCustomObject]$IndexApplyIgnore = $IndexTable |
				Where-Object -FilterScript { $_.Name -ieq $ApplyIgnoreRaw }
				Select-Object -First 1
			[String]$DestinationFilePath = Join-Path -Path $ClamAVDatabaseRoot -ChildPath $IndexApplyIgnore.DatabaseFileName
			If (
				$DestinationFilePath -iin $AssetsApplyPaths -or
				$IndexApplyIgnore.Name -iin $AssetsApplyIssues
			) {
				Continue
			}
			Try {
				Copy-Item -LiteralPath $IndexApplyIgnore.FilePath -Destination $DestinationFilePath -Confirm:$False
				$AssetsApplyPaths += $DestinationFilePath
			}
			Catch {
				Write-GitHubActionsError -Message "Unable to apply ClamAV unofficial asset ``$($IndexApplyIgnore.Name)``: $_"
				$AssetsApplyIssues += $IndexApplyIgnore.Name
			}
		}
	}
	Write-Output -InputObject @{
		ApplyIssues = $AssetsApplyIssues
		ApplyPaths = $AssetsApplyPaths
		IndexTable = $IndexTable
	}
}
Function Register-YaraUnofficialAssets {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][AllowEmptyCollection()][Alias('Selections')][RegEx[]]$Selection
	)
	[PSCustomObject[]]$IndexTable = Import-Csv -LiteralPath $YaraUnofficialAssetsIndexFilePath @ImportCsvParameters_Tsv |
		Where-Object -FilterScript { $_.Type -ine 'Group' -and $_.Path.Length -gt 0 } |
		ForEach-Object -Process { [PSCustomObject]@{
			Type = $_.Type
			Name = $_.Name
			FilePath = Join-Path -Path $YaraUnofficialAssetsRoot -ChildPath $_.Path
			Select = Test-StringMatchRegExs -Item $_.Name -Matchers $Selection
		} } |
		Sort-Object -Property @('Type', 'Name')
	[PSCustomObject]@{
		All = $IndexTable.Count
		Select = $IndexTable |
			Where-Object -FilterScript { $_.Select } |
			Measure-Object |
			Select-Object -ExpandProperty 'Count'
	} |
		Format-List -Property '*' |
		Out-String -Width 120 |
		Write-Host
	$IndexTable |
		Format-Table -Property @(
			'Type',
			'Name',
			@{ Expression = 'Select'; Alignment = 'Right' }
		) -AutoSize -Wrap |
		Out-String -Width 120 |
		Write-Host
	Write-Output -InputObject $IndexTable
}
Function Update-ClamAV {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Enter-GitHubActionsLogGroup -Title 'Update ClamAV via FreshClam.'
	Try {
		freshclam --verbose
		If ($LASTEXITCODE -ne 0) {
			Throw "Exit code is $LASTEXITCODE."
		}
	}
	Catch {
		Write-GitHubActionsWarning -Message @"
Unexpected issues when update ClamAV via FreshClam: $_
This is fine, but the local assets maybe outdated.
"@
	}
	Exit-GitHubActionsLogGroup
}
Export-ModuleMember -Function @(
	'Import-NetworkTarget',
	'Register-ClamAVUnofficialAssets',
	'Register-YaraUnofficialAssets',
	'Update-ClamAV'
)
