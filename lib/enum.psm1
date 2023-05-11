#Requires -PSEdition Core -Version 7.2
Enum ScanVirusInputTableMarkup {
	CSV = 1
	CSVM = 2
	CSVS = 3
	JSON = 4
	TSV = 5
	YAML = 6
	YML = 6
}
Enum ScanVirusStepSummaryChoices {
	None = 0
	Clone = 1
	Redirect = 2
}
