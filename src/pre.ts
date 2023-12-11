import { debug as ghactionsDebug, error as ghactionsError, getBooleanInput as ghactionsGetBooleanInput, saveState as ghactionsSaveState } from "@actions/core";
import { installSoftware } from "./checkout.js";
try {
	if (ghactionsGetBooleanInput("operate_presetup", {
		required: true,
		trimWhitespace: false
	})) {
		await installSoftware();
	} else {
		ghactionsDebug("Setup at the pre step is disabled, will happen at the main step instead.");
	}
} catch (error) {
	ghactionsError(error);
	process.exitCode = 1;
}
