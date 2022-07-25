[Hashtable]$GitCommitsPropertyToken = @{ Name = 'CommitHash'; Placeholder = '%H' }
[Hashtable[]]$GitCommitsProperties = @(
	@{ Name = 'AuthorDate'; Placeholder = '%aI'; Type = [DateTime] },
	@{ Name = 'AuthorEmail'; Placeholder = '%ae' },
	@{ Name = 'AuthorName'; Placeholder = '%an' },
	@{ Name = 'Body'; Placeholder = '%b'; IsMultipleLine = $True },
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
	@{ Name = 'ShortenedReflogSelector'; Placeholder = '%gd' },
	@{ Name = 'Subject'; Placeholder = '%s' },
	@{ Name = 'TreeHash'; Placeholder = '%T' }
)
[String]$GitExpressionDelimiter = ': '
[String]$GitExpressionSingleLine = 'git --no-pager log --all --format="{0}"'
[String]$GitExpressionMultipleLine = 'git --no-pager show --format="{1}" {0}'
Function Get-GitCommits {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param ()
	[Hashtable[]]$GitCommits = [String[]](Invoke-Expression -Command ($GitExpressionSingleLine -f $GitCommitsPropertyToken.Placeholder)) | ForEach-Object -Process {
		Return @{ "$($GitCommitsPropertyToken.Name)" = $_ }
	}
	ForEach ($GitCommitsProperty In $GitCommitsProperties) {
		If ($GitCommitsProperty.IsMultipleLine) {
			For ($GitCommitIndex = 0; $GitCommitIndex -ilt $GitCommits.Count; $GitCommitIndex++) {
				$GitCommits[$GitCommitIndex][$GitCommitsProperty.Name] = [String[]](Invoke-Expression -Command ($GitExpressionMultipleLine -f @($GitCommits[$GitCommitIndex][$GitCommitsPropertyToken.Name], $GitCommitsProperty.Placeholder))) -join "`n" -ireplace '^(?:\s*\r?\n)+|(?:\s*\r?\n)+$', ''
			}
		} Else {
			[String[]]$Results = Invoke-Expression -Command ($GitExpressionSingleLine -f "$($GitCommitsPropertyToken.Placeholder)$($GitExpressionDelimiter)$($GitCommitsProperty.Placeholder)")
			If ($GitCommits.Count -ine $Results.Count) {
				Write-Error -Message 'Git database was modified during process!' -Category 'ResourceUnavailable' -ErrorId 'Git.DatabaseModifiedOnRead'
				Return @()
			}
			For ($ResultsIndex = 0; $ResultsIndex -ilt $Results.Count; $ResultsIndex++) {
				[String[]]$ResultRaw = $Results[$ResultsIndex] -isplit [RegEx]::Escape($GitExpressionDelimiter)
				[String]$ResultToken = $ResultRaw[0]
				[String[]]$ResultContent = $ResultRaw[1..(($ResultRaw.Count -igt 1) ? ($ResultRaw.Count - 1) : 1)]
				If ($GitCommits[$ResultsIndex][$GitCommitsPropertyToken.Name] -ine $ResultToken) {
					Write-Error -Message 'Git database was modified during process!' -Category 'ResourceUnavailable' -ErrorId 'Git.DatabaseModifiedOnRead'
					Return @()
				}
				If ($GitCommitsProperty.IsArray) {
					$GitCommits[$ResultsIndex][$GitCommitsProperty.Name] = $ResultContent
				} ElseIf ($Null -ine $GitCommitsProperty.Type) {
					$GitCommits[$ResultsIndex][$GitCommitsProperty.Name] = ($ResultContent -join $GitExpressionDelimiter) -as $GitCommitsProperty.Type
				} Else {
					$GitCommits[$ResultsIndex][$GitCommitsProperty.Name] = $ResultContent -join $GitExpressionDelimiter
				}
			}
		}
	}
	Return ($GitCommits | ForEach-Object -Process {
		Return [PSCustomObject]$_
	})
}
Export-ModuleMember -Function @(
	'Get-GitCommits'
)
