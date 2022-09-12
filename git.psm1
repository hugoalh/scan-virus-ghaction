#Requires -PSEdition Core
#Requires -Version 7.2
Import-Module -Name @(
	(Join-Path -Path $PSScriptRoot -ChildPath 'internal\token.psm1')
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
	@{ Name = 'ParentHashes'; Placeholder = '%P'; IsArray = $True },
	@{ Name = 'ReflogIdentityEmail'; Placeholder = '%ge' },
	@{ Name = 'ReflogIdentityName'; Placeholder = '%gn' },
	@{ Name = 'ReflogSelector'; Placeholder = '%gD' },
	@{ Name = 'ReflogSubject'; Placeholder = '%gs' },
	@{ Name = 'Subject'; Placeholder = '%s' },
	@{ Name = 'TreeHash'; Placeholder = '%T' }
)
[String]$GitCommitsInformationExpressionMultipleLine = 'git --no-pager show --format="{1}" --no-color --no-patch {0}'
[String]$GitCommitsInformationExpressionSingleLine = 'git --no-pager log --all --format="{0}"'
[Hashtable]$GitCommitsPropertySorter = $GitCommitsProperties |
	Where-Object -FilterScript { $_.AsSort } |
	Select-Object -First 1
[Hashtable]$GitCommitsPropertyTokenizer = $GitCommitsProperties |
	Where-Object -FilterScript { $_.AsIndex } |
	Select-Object -First 1
[Hashtable[]]$GitCommitsPropertyRemain = $GitCommitsProperties |
	Where-Object -FilterScript { $_.Name -ine $GitCommitsPropertyTokenizer.Name }
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
			[String]$GitCommitsInformationQuery = "$DelimiterPerCommitStart%n$(
				$GitCommitsProperties |
					Select-Object -ExpandProperty 'Placeholder' |
					Join-String -Separator "%n$DelimiterPerCommitProperty%n"
			)%n$DelimiterPerCommitEnd"
			[String[]]$Raw = Invoke-Expression -Command "git --no-pager log --all --format=`"$GitCommitsInformationQuery`" --no-color"
			If ($LASTEXITCODE -ine 0) {
				Throw (
					$Raw |
						Join-String -Separator "`n"
				)
			}
			[UInt32]$DelimiterStartCount = (
				$Raw |
					Select-String -Pattern [RegEx]::Escape($DelimiterPerCommitStart) -AllMatches
			).Matches.Count
			[UInt64]$DelimiterPropertyCount = (
				$Raw |
					Select-String -Pattern [RegEx]::Escape($DelimiterPerCommitProperty) -AllMatches
			).Matches.Count
			[UInt32]$DelimiterEndCount = (
				$Raw |
					Select-String -Pattern [RegEx]::Escape($DelimiterPerCommitEnd) -AllMatches
			).Matches.Count
			If (
				($DelimiterStartCount -ine $DelimiterEndCount) -or
				($DelimiterPropertyCount / $DelimiterTokenCountPerCommit -ine $DelimiterStartCount)
			) {
				Continue
			}
			[Hashtable[]]$Result = $Raw |
				ForEach-Object -Process { @{ "$($GitCommitsPropertyTokenizer.Name)" = $_ } }
			For ([UInt32]$CommitIndex = 0; $CommitIndex -ilt $Result.Count; $CommitIndex++) {
				
			}
			ForEach ($GitCommitsProperty In $GitCommitsProperties) {
				If ($GitCommitsProperty.Name -ieq $GitCommitsPropertyTokenizer.Name) {
					Continue
				}
				If ($GitCommitsProperty.IsMultipleLine) {
					For ([UInt32]$CommitIndex = 0; $CommitIndex -ilt $Result.Count; $CommitIndex++) {
						$Result[$CommitIndex][$GitCommitsProperty.Name] = [String[]](Invoke-Expression -Command ($GitCommitsInformationExpressionMultipleLine -f @($Result[$CommitIndex][$GitCommitsPropertyTokenizer.Name], $GitCommitsProperty.Placeholder))) -join "`n" -ireplace '^(?:\s*\r?\n)+|(?:\s*\r?\n)+$', ''
					}
					Continue
				}
				[String[]]$ExpressionOutput = Invoke-Expression -Command ($GitCommitsInformationExpressionSingleLine -f $GitCommitsProperty.Placeholder)
				For ([UInt32]$Row = 0; $Row -ilt $ExpressionOutput.Count; $Row++) {
					[String]$Value = $ExpressionOutput[$Row]
					If ($GitCommitsProperty.IsArray) {
						$Result[$Row][$GitCommitsProperty.Name] = $Value -isplit ' '
					}
					ElseIf ($Null -ine $GitCommitsProperty.Type) {
						$Result[$Row][$GitCommitsProperty.Name] = $Value -as $GitCommitsProperty.Type
					}
					Else {
						$Result[$Row][$GitCommitsProperty.Name] = $Value
					}
				}
			}
			Return ($Result | ForEach-Object -Process {
				Return [PSCustomObject]$_
			} | Sort-Object -Property 'AuthorDate')
		}
		Catch {
			Throw "Unexpected Git database issue: $_"
		}
	}
}
Export-ModuleMember -Function @(
	'Get-GitCommitsInformation'
)
