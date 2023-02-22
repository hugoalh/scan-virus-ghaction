#Requires -PSEdition Core
#Requires -Version 7.3
Import-Module -Name @(
	(Join-Path -Path $PSScriptRoot -ChildPath 'token.psm1')
) -Scope 'Local'
[Hashtable[]]$GitCommitsProperties = @(
	@{ Name = 'AuthorDate'; Placeholder = '%aI'; AsSort = $True; AsType = [DateTime] },
	@{ Name = 'AuthorEmail'; Placeholder = '%ae' },
	@{ Name = 'AuthorName'; Placeholder = '%an' },
	@{ Name = 'Body'; Placeholder = '%b'; IsMultipleLine = $True },
	@{ Name = 'CommitHash'; Placeholder = '%H'; AsIndex = $True },
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
[Hashtable]$GitCommitsPropertyIndexer = $GitCommitsProperties |
	Where-Object -FilterScript { $_.AsIndex } |
	Select-Object -First 1
[Hashtable]$GitCommitsPropertySorter = $GitCommitsProperties |
	Where-Object -FilterScript { $_.AsSort } |
	Select-Object -First 1
[UInt16]$DelimiterTokenCountPerCommit = $GitCommitsProperties.Count - 1
Function Get-GitCommits {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Alias('IncludeAllBranches')][Switch]$AllBranches,
		[Alias('IncludeReflogs')][Switch]$Reflogs
	)
	[String]$IsGitRepositoryResult = git rev-parse --is-inside-work-tree |
		Join-String -Separator "`n"
	If ($IsGitRepositoryResult -ine 'True') {
		Write-Output -InputObject @{
			Success = $False
			Result = 'Workspace is not a Git repository!'
		}
		Return
	}
	Do {
		Try {
			[String]$DelimiterPerCommitStart = "=====S:$(New-RandomToken)====="
			[String]$DelimiterPerCommitProperty = "=====P:$(New-RandomToken)====="
			[String]$DelimiterPerCommitEnd = "=====E:$(New-RandomToken)====="
			[String[]]$Raw0 = Invoke-Expression -Command "git --no-pager log$($AllBranches ? ' --all' : '') --format=`"$DelimiterPerCommitStart%n$(
				$GitCommitsProperties |
					Select-Object -ExpandProperty 'Placeholder' |
					Join-String -Separator "%n$DelimiterPerCommitProperty%n"
			)%n$DelimiterPerCommitEnd`" --no-color$($Reflogs ? ' --reflog' : '')"
			If ($LASTEXITCODE -ine 0) {
				Throw (
					$Raw0 |
						Join-String -Separator "`n"
				)
			}
		}
		Catch {
			Write-Output -InputObject @{
				Success = $False
				Result = "Unexpected Git database issue! $_"
			}
			Return
		}
		$Raw0LineGroup = $Raw0 |
			Group-Object -CaseSensitive
		[UInt64]$DelimiterStartCount = $Raw0LineGroup |
			Where-Object -FilterScript { $_.Name -ceq $DelimiterPerCommitStart } |
			Select-Object -ExpandProperty 'Count'
		[UInt64]$DelimiterPropertyCount = $Raw0LineGroup |
			Where-Object -FilterScript { $_.Name -ceq $DelimiterPerCommitProperty } |
			Select-Object -ExpandProperty 'Count'
		[UInt64]$DelimiterEndCount = $Raw0LineGroup |
			Where-Object -FilterScript { $_.Name -ceq $DelimiterPerCommitEnd } |
			Select-Object -ExpandProperty 'Count'
	}
	While (
		($DelimiterStartCount -ine $DelimiterEndCount) -or
		(($DelimiterPropertyCount / $DelimiterTokenCountPerCommit) -ine $DelimiterStartCount)
	)
	[String[]]$Raw1 = (
		$Raw0 |
			Select-Object -Skip 1 |
			Select-Object -SkipLast 1 |
			Join-String -Separator "`n"
	) -csplit ([RegEx]::Escape("`n$DelimiterPerCommitEnd`n$DelimiterPerCommitStart`n"))
	[PSCustomObject[]]$Result = @()
	For ([UInt64]$Raw1Line = 0; $Raw1Line -ilt $Raw1.Count; $Raw1Line++) {
		[String[]]$Raw2 = $Raw1[$Raw1Line] -csplit ([RegEx]::Escape("`n$DelimiterPerCommitProperty`n"))
		If ($GitCommitsProperties.Count -ine $Raw2.Count) {
			Write-Output -InputObject @{
				Success = $False
				Result = 'Unexpected Git database issue! Columns are not match!'
			}
			Return
		}
		[Hashtable]$Raw2Table = @{}
		For ([UInt16]$Raw2Line = 0; $Raw2Line -ilt $Raw2.Count; $Raw2Line++) {
			[Hashtable]$GitCommitsPropertiesCurrent = $GitCommitsProperties[$Raw2Line]
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
	Write-Output -InputObject @{
		Success = $True
		Result = $Result |
			Sort-Object -Property $GitCommitsPropertySorter.Name
	}
}
Export-ModuleMember -Function @(
	'Get-GitCommits'
)
