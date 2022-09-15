#Requires -PSEdition Core
#Requires -Version 7.2
Import-Module -Name @(
	(Join-Path -Path $PSScriptRoot -ChildPath 'token.psm1')
) -Scope 'Local'
[Hashtable[]]$GitCommitsProperties = @(
	@{ Name = 'AuthorDate'; Placeholder = '%aI'; AsSort = $True; Type = [DateTime] },
	@{ Name = 'AuthorEmail'; Placeholder = '%ae' },
	@{ Name = 'AuthorName'; Placeholder = '%an' },
	@{ Name = 'Body'; Placeholder = '%b'; IsMultipleLine = $True },
	@{ Name = 'CommitHash'; Placeholder = '%H'; AsIndex = $True },
	@{ Name = 'CommitterDate'; Placeholder = '%cI'; Type = [DateTime] },
	@{ Name = 'CommitterEmail'; Placeholder = '%ce' },
	@{ Name = 'CommitterName'; Placeholder = '%cn' },
	@{ Name = 'Encoding'; Placeholder = '%e' },
	@{ Name = 'GPGSignatureKey'; Placeholder = '%GK' },
	@{ Name = 'GPGSignatureKeyFingerprint'; Placeholder = '%GF' },
	@{ Name = 'GPGSignaturePrimaryKeyFingerprint'; Placeholder = '%GP' },
	@{ Name = 'GPGSignatureSigner'; Placeholder = '%GS' },
	@{ Name = 'GPGSignatureStatus'; Placeholder = '%G?' },
	@{ Name = 'GPGSignatureTrustLevel'; Placeholder = '%GP' },
	@{ Name = 'Notes'; Placeholder = '%N'; IsMultipleLine = $True },
	@{ Name = 'ParentHashes'; Placeholder = '%P'; IsArraySpace = $True },
	@{ Name = 'ReflogIdentityEmail'; Placeholder = '%ge' },
	@{ Name = 'ReflogIdentityName'; Placeholder = '%gn' },
	@{ Name = 'ReflogSelector'; Placeholder = '%gD' },
	@{ Name = 'ReflogSubject'; Placeholder = '%gs' },
	@{ Name = 'Subject'; Placeholder = '%s' },
	@{ Name = 'TreeHash'; Placeholder = '%T' }
) |
	Sort-Object -Property 'Name'
[Hashtable]$GitCommitsPropertySorter = $GitCommitsProperties |
	Where-Object -FilterScript { $_.AsSort } |
	Select-Object -First 1
[UInt16]$DelimiterTokenCountPerCommit = $GitCommitsProperties.Count - 1
Function Get-GitCommitsInformation {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param ()
	While ($True) {
		Try {
			[String]$DelimiterPerCommitStart = "=====S:$(New-RandomToken -Length 32)====="
			[String]$DelimiterPerCommitProperty = "=====B:$(New-RandomToken -Length 32)====="
			[String]$DelimiterPerCommitEnd = "=====E:$(New-RandomToken -Length 32)====="
			[String[]]$Raw = Invoke-Expression -Command "git --no-pager log --all --format=`"$DelimiterPerCommitStart%n$(
				$GitCommitsProperties |
					Select-Object -ExpandProperty 'Placeholder' |
					Join-String -Separator "%n$DelimiterPerCommitProperty%n"
			)%n$DelimiterPerCommitEnd`" --no-color --reflog --reverse"
			If ($LASTEXITCODE -ine 0) {
				Throw (
					$Raw |
						Join-String -Separator "`n"
				)
			}
			[UInt64]$DelimiterStartCount = (
				$Raw |
					Select-String -Pattern "^$([RegEx]::Escape($DelimiterPerCommitStart))$" -Raw -CaseSensitive -NoEmphasis -AllMatches
			).Count
			[UInt64]$DelimiterPropertyCount = (
				$Raw |
					Select-String -Pattern "^$([RegEx]::Escape($DelimiterPerCommitProperty))$" -Raw -CaseSensitive -NoEmphasis -AllMatches
			).Count
			[UInt64]$DelimiterEndCount = (
				$Raw |
					Select-String -Pattern "^$([RegEx]::Escape($DelimiterPerCommitEnd))$" -Raw -CaseSensitive -NoEmphasis -AllMatches
			).Count
			If (
				($DelimiterStartCount -ine $DelimiterEndCount) -or
				($DelimiterPropertyCount / $DelimiterTokenCountPerCommit -ine $DelimiterStartCount)
			) {
				Continue
			}
			[PSCustomObject[]]$Result = @()
			[Hashtable]$ResultCommitStorage = @{}
			[UInt16]$GitCommitsPropertiesIndex = 0
			For ([UInt64]$RawLine = 0; $RawLine -ilt $Raw.Count; $RawLine++) {
				[String]$RawLineCurrent = $Raw[$RawLine]
				If (
					$RawLineCurrent -ceq $DelimiterPerCommitStart -or
					$RawLineCurrent -ceq $DelimiterPerCommitProperty
				) {
					Continue
				}
				If ($RawLineCurrent -ceq $DelimiterPerCommitEnd) {
					$Result += [PSCustomObject]$ResultCommitStorage
					$ResultCommitStorage = @{}
					$GitCommitsPropertiesIndex = 0
					Continue
				}
				[String[]]$RawRemain = $Raw |
					Select-Object -Skip $RawLine
				[UInt64]$RawNextDelimiterIndex = @(
					$RawRemain.IndexOf($DelimiterPerCommitStart)
					$RawRemain.IndexOf($DelimiterPerCommitProperty)
					$RawRemain.IndexOf($DelimiterPerCommitEnd)
				) |
					Where-Object -FilterScript { $_ -ige 0 } |
					Measure-Object -Minimum |
					Select-Object -ExpandProperty 'Minimum'
				[Hashtable]$GitCommitsPropertiesCurrent = $GitCommitsProperties[$GitCommitsPropertiesIndex]
				[String[]]$Value = $RawRemain[0..($RawNextDelimiterIndex - 1)]
				If ($GitCommitsPropertiesCurrent.IsArraySpace) {
					$ResultCommitStorage[$GitCommitsPropertiesCurrent.Name] = $Value -join "`n" -isplit ' '
				}
				ElseIf ($GitCommitsPropertiesCurrent.IsMultipleLine) {
					$ResultCommitStorage[$GitCommitsPropertiesCurrent.Name] = $Value -join "`n"
				}
				ElseIf ($GitCommitsPropertiesCurrent.Type) {
					$ResultCommitStorage[$GitCommitsPropertiesCurrent.Name] = $Value -join "`n" -as $GitCommitsPropertiesCurrent.Type
				}
				Else {
					$ResultCommitStorage[$GitCommitsPropertiesCurrent.Name] = $Value -join "`n"
				}
				$RawLine += $RawNextDelimiterIndex - 1
				$GitCommitsPropertiesIndex += 1
			}
			$Result |
				Sort-Object -Property $GitCommitsPropertySorter.Name |
				Write-Output
			Return
		}
		Catch {
			Throw "Unexpected Git database issue: $_"
		}
	}
}
Export-ModuleMember -Function @(
	'Get-GitCommitsInformation'
)
