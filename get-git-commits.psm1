[hashtable]$GitCommitsInformationToken = @{ Name = 'CommitHash'; Placeholder = '%H' }
[hashtable[]]$GitCommitsInformations = @(
	@{ Name = 'AbbreviatedCommitHash'; Placeholder = '%h' },
	@{ Name = 'AbbreviatedParentHashes'; Placeholder = '%p'; IsArray = $true },
	@{ Name = 'AbbreviatedTreeHash'; Placeholder = '%t' },
	@{ Name = 'AuthorDate'; Placeholder = '%aI'; Type = [datetime] },
	@{ Name = 'AuthorEmail'; Placeholder = '%ae' },
	@{ Name = 'AuthorName'; Placeholder = '%an' },
	@{ Name = 'Body'; Placeholder = '%b'; IsMultipleLine = $true },
	@{ Name = 'CommitterDate'; Placeholder = '%cI'; Type = [datetime] },
	@{ Name = 'CommitterEmail'; Placeholder = '%ce' },
	@{ Name = 'CommitterName'; Placeholder = '%cn' },
	@{ Name = 'Encoding'; Placeholder = '%e' },
	@{ Name = 'GPGSignatureKey'; Placeholder = '%GK' },
	@{ Name = 'GPGSignatureKeyFingerprint'; Placeholder = '%GF' },
	@{ Name = 'GPGSignaturePrimaryKeyFingerprint'; Placeholder = '%GP' },
	@{ Name = 'GPGSignatureSigner'; Placeholder = '%GS' },
	@{ Name = 'GPGSignatureStatus'; Placeholder = '%G?' },
	@{ Name = 'GPGSignatureTrustLevel'; Placeholder = '%GP' },
	@{ Name = 'Notes'; Placeholder = '%N'; IsMultipleLine = $true },
	@{ Name = 'ParentHashes'; Placeholder = '%P'; IsArray = $true },
	@{ Name = 'ReflogIdentityEmail'; Placeholder = '%ge' },
	@{ Name = 'ReflogIdentityName'; Placeholder = '%gn' },
	@{ Name = 'ReflogSelector'; Placeholder = '%gD' },
	@{ Name = 'ReflogSubject'; Placeholder = '%gs' },
	@{ Name = 'ShortenedReflogSelector'; Placeholder = '%gd' },
	@{ Name = 'Subject'; Placeholder = '%s' },
	@{ Name = 'TreeHash'; Placeholder = '%T' }
)
[string]$GitLogExpressionDelimiter = ' '
[string]$GitLogExpressionSingleLine = 'git --no-pager log --all --format="{0}"'
[string]$GitLogExpressionMultipleLine = 'git --no-pager show --format="{1}" {0}'
function Get-GitCommits {
	[CmdletBinding()][OutputType([pscustomobject[]])]
	param ()
	[hashtable[]]$GitCommits = [string[]](Invoke-Expression -Command ($GitLogExpressionSingleLine -f $GitCommitsInformationToken.Placeholder)) | ForEach-Object -Process { return @{ "$($GitCommitsInformationToken.Name)" = $_ } }
	foreach ($GitCommitsInformation in $GitCommitsInformations) {
		if ($GitCommitsInformation.IsMultipleLine) {
			for ($GitCommitIndex = 0; $GitCommitIndex -lt $GitCommits.Count; $GitCommitIndex++) {
				$GitCommits[$GitCommitIndex][$GitCommitsInformation.Name] = [string[]](Invoke-Expression -Command ($GitLogExpressionMultipleLine -f @($GitCommits[$GitCommitIndex][$GitCommitsInformationToken.Name], $GitCommitsInformation.Placeholder))) -join "`n" -replace '^(?:\s*\r?\n)+|(?:\s*\r?\n)+$', ''
			}
		} else {
			[string[]]$Results = Invoke-Expression -Command ($GitLogExpressionSingleLine -f "$($GitCommitsInformationToken.Placeholder)$($GitLogExpressionDelimiter)$($GitCommitsInformation.Placeholder)")
			if ($GitCommits.Count -ne $Results.Count) {
				throw 'Git database was modified during process!'
			}
			for ($ResultsIndex = 0; $ResultsIndex -lt $Results.Count; $ResultsIndex++) {
				[string[]]$ResultRaw = $Results[$ResultsIndex] -split $GitLogExpressionDelimiter
				[string]$ResultToken = $ResultRaw[0]
				[string[]]$ResultContentRaw = $ResultRaw[1..(($ResultRaw.Count -gt 1) ? ($ResultRaw.Count - 1) : 1)]
				if ($GitCommits[$ResultsIndex][$GitCommitsInformationToken.Name] -ne $ResultToken) {
					throw 'Git database was modified during process!'
				}
				$ResultContent = $null
				if ($GitCommitsInformation.IsArray) {
					$ResultContent = $ResultContentRaw
				} elseif ($null -ne $GitCommitsInformation.Type) {
					$ResultContent = $ResultContentRaw -join $GitLogExpressionDelimiter -as $GitCommitsInformation.Type
				} else {
					$ResultContent = $ResultContentRaw -join $GitLogExpressionDelimiter
				}
				$GitCommits[$ResultsIndex][$GitCommitsInformation.Name] = $ResultContent
			}
		}
	}
	return ($GitCommits | ForEach-Object -Process { return [pscustomobject]$_ })
}
Export-ModuleMember -Function 'Get-GitCommits'
