[hashtable]$GitCommitsPropertyToken = @{ Name = 'CommitHash'; Placeholder = '%H' }
[hashtable[]]$GitCommitsProperties = @(
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
[string]$GitExpressionDelimiter = ' '
[string]$GitExpressionSingleLine = 'git --no-pager log --all --format="{0}"'
[string]$GitExpressionMultipleLine = 'git --no-pager show --format="{1}" {0}'
function Get-GitCommits {
	[CmdletBinding()][OutputType([pscustomobject[]])]
	param (
		[ValidatePattern('^.+$')][string[]]$Filter = @('^.+$')
	)
	[hashtable[]]$GitCommits = [string[]](Invoke-Expression -Command ($GitExpressionSingleLine -f $GitCommitsPropertyToken.Placeholder)) | ForEach-Object -Process {
		return @{ "$($GitCommitsPropertyToken.Name)" = $_ }
	}
	foreach ($GitCommitsProperty in $GitCommitsProperties) {
		[bool]$FilterIsMatch = $false
		foreach ($Item in $Filter) {
			if ($GitCommitsProperty -match $Item) {
				$FilterIsMatch = $true
				break
			}
		}
		if ($FilterIsMatch -eq $false) {
			continue
		}
		if ($GitCommitsProperty.IsMultipleLine) {
			for ($GitCommitIndex = 0; $GitCommitIndex -lt $GitCommits.Count; $GitCommitIndex++) {
				$GitCommits[$GitCommitIndex][$GitCommitsProperty.Name] = [string[]](Invoke-Expression -Command ($GitExpressionMultipleLine -f @($GitCommits[$GitCommitIndex][$GitCommitsPropertyToken.Name], $GitCommitsProperty.Placeholder))) -join "`n" -replace '^(?:\s*\r?\n)+|(?:\s*\r?\n)+$', ''
			}
		} else {
			[string[]]$Results = Invoke-Expression -Command ($GitExpressionSingleLine -f "$($GitCommitsPropertyToken.Placeholder)$($GitExpressionDelimiter)$($GitCommitsProperty.Placeholder)")
			if ($GitCommits.Count -ne $Results.Count) {
				throw 'Git database was modified during process!'
			}
			for ($ResultsIndex = 0; $ResultsIndex -lt $Results.Count; $ResultsIndex++) {
				[string[]]$ResultRaw = $Results[$ResultsIndex] -split [regex]::Escape($GitExpressionDelimiter)
				[string]$ResultToken = $ResultRaw[0]
				[string[]]$ResultContentRaw = $ResultRaw[1..(($ResultRaw.Count -gt 1) ? ($ResultRaw.Count - 1) : 1)]
				if ($GitCommits[$ResultsIndex][$GitCommitsPropertyToken.Name] -ne $ResultToken) {
					throw 'Git database was modified during process!'
				}
				$ResultContent = $null
				if ($GitCommitsProperty.IsArray) {
					$ResultContent = $ResultContentRaw
				} elseif ($null -ne $GitCommitsProperty.Type) {
					$ResultContent = $ResultContentRaw -join $GitExpressionDelimiter -as $GitCommitsProperty.Type
				} else {
					$ResultContent = $ResultContentRaw -join $GitExpressionDelimiter
				}
				$GitCommits[$ResultsIndex][$GitCommitsProperty.Name] = $ResultContent
			}
		}
	}
	return ($GitCommits | ForEach-Object -Process {
		return [pscustomobject]$_
	})
}
Export-ModuleMember -Function 'Get-GitCommits'
