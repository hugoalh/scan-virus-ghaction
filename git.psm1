#Requires -PSEdition Core
#Requires -Version 7.2
Import-Module -Name @(
	(Join-Path -Path $PSScriptRoot -ChildPath 'token.psm1')
) -Scope 'Local'
[Hashtable[]]$GitCommitsProperties = @(
	@{ Name = 'AuthorDate'; Placeholder = '%aI'; AsSort = $True; Require = $True; AsType = [DateTime] },
	@{ Name = 'AuthorEmail'; Placeholder = '%ae' },
	@{ Name = 'AuthorName'; Placeholder = '%an' },
	@{ Name = 'Body'; Placeholder = '%b'; IsMultipleLine = $True },
	@{ Name = 'CommitHash'; Placeholder = '%H'; AsIndex = $True; Require = $True },
	@{ Name = 'CommitterDate'; Placeholder = '%cI'; AsType = [DateTime] },
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
[Hashtable[]]$GitCommitsRequireProperties =  $GitCommitsProperties |
	Where-Object -FilterScript { $_.Require }
Function Get-GitCommitsInformation {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Alias('Properties')][String[]]$Property,
		[Alias('IncludeAllBranches')][Switch]$AllBranches,
		[Alias('IncludeReflogs')][Switch]$Reflogs
	)
	[String[]]$PropertySelect = (
		$GitCommitsRequireProperties |
			Select-Object -ExpandProperty 'Name'
	) + $Property |
		ForEach-Object -Process { $_.ToLower() } |
		Select-Object -Unique
	[Hashtable[]]$GitCommitsPropertiesSelect = $GitCommitsProperties |
		Where-Object -FilterScript { $_.Name -iin $PropertySelect }
	[UInt16]$DelimiterTokenCountPerCommit = $GitCommitsPropertiesSelect.Count - 1
	While ($True) {
		Try {
			[String]$DelimiterPerCommitStart = "=====S:$(New-RandomToken -Length 32)====="
			[String]$DelimiterPerCommitProperty = "=====B:$(New-RandomToken -Length 32)====="
			[String]$DelimiterPerCommitEnd = "=====E:$(New-RandomToken -Length 32)====="
			[String[]]$Raw0 = Invoke-Expression -Command "git --no-pager log$($AllBranches ? ' --all' : '') --format=`"$DelimiterPerCommitStart%n$(
				$GitCommitsPropertiesSelect |
					Select-Object -ExpandProperty 'Placeholder' |
					Join-String -Separator "%n$DelimiterPerCommitProperty%n"
			)%n$DelimiterPerCommitEnd`" --no-color$($Reflogs ? ' --reflog' : '')"
			If ($LASTEXITCODE -ine 0) {
				Throw (
					$Raw0 |
						Join-String -Separator "`n"
				)
			}
			$Raw0LineGroup = Group-Object -InputObject $Raw0 -CaseSensitive
			[UInt64]$DelimiterStartCount = $Raw0LineGroup |
				Where-Object -FilterScript { $_.Name -ceq $DelimiterPerCommitStart } |
				Select-Object -First 1 |
				Select-Object -ExpandProperty 'Count'
			[UInt64]$DelimiterPropertyCount = $Raw0LineGroup |
				Where-Object -FilterScript { $_.Name -ceq $DelimiterPerCommitProperty } |
				Select-Object -First 1 |
				Select-Object -ExpandProperty 'Count'
			[UInt64]$DelimiterEndCount = $Raw0LineGroup |
				Where-Object -FilterScript { $_.Name -ceq $DelimiterPerCommitEnd } |
				Select-Object -First 1 |
				Select-Object -ExpandProperty 'Count'
			If (
				($DelimiterStartCount -ine $DelimiterEndCount) -or
				($DelimiterPropertyCount / $DelimiterTokenCountPerCommit -ine $DelimiterStartCount)
			) {
				Continue
			}
			[String[]]$Raw1 = (
				$Raw0 |
					Select-Object -Skip 1 |
					Select-Object -SkipLast 1 |
					Join-String -Separator "`n"
			) -isplit ([RegEx]::Escape("$($DelimiterPerCommitEnd)$($DelimiterPerCommitStart)"))
			[PSCustomObject[]]$Result = @()
			For ([UInt64]$Raw1Line = 0; $Raw1Line -ilt $Raw1.Count; $Raw1Line++) {
				[String[]]$Raw2 = $Raw1[$Raw1Line] -isplit ([RegEx]::Escape($DelimiterPerCommitProperty))
				If ($GitCommitsPropertiesSelect.Count -ine $Raw2.Count) {
					Throw 'Columns are not match!'
				}
				[Hashtable]$Raw2Table = @{}
				For ([UInt16]$Raw2Line = 0; $Raw2Line -ilt $Raw2.Count; $Raw2Line++) {
					[Hashtable]$GitCommitsPropertiesCurrent = $GitCommitsPropertiesSelect[$Raw2Line]
					[String]$Value = $Raw2[$Raw2Line]
					If ($GitCommitsPropertiesCurrent.IsArraySpace) {
						$Raw2Table[$GitCommitsPropertiesCurrent.Name] = $Value -isplit ' '
					}
					ElseIf ($GitCommitsPropertiesCurrent.AsType) {
						$Raw2Table[$GitCommitsPropertiesCurrent.Name] = $Value -as $GitCommitsPropertiesCurrent.AsType
					}
					Else {
						$Raw2Table[$GitCommitsPropertiesCurrent.Name] = $Value
					}
				}
				$Result += [PSCustomObject]$Raw2Table
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
