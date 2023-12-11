import { debug as ghactionsDebug, error as ghactionsError, getBooleanInput as ghactionsGetBooleanInput, saveState as ghactionsSaveState } from "@actions/core";
try {
	if (ghactionsGetBooleanInput("operate_cleanup", {
		required: true,
		trimWhitespace: false
	})) {
		
	} else {
		ghactionsDebug("Clean up at the post step is disabled.");
	}
} catch (error) {
	ghactionsError(error);
	process.exitCode = 1;
}
