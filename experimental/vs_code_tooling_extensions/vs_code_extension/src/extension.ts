import * as vs from 'vscode';
import { DartCodeExports, Sidebar } from 'dart-code-api';

const extensionName = "flutter-tooling-extension-sample";

export async function activate(context: vs.ExtensionContext): Promise<void> {
	const dartCode = vs.extensions.getExtension("Dart-Code.dart-code");
	await dartCode?.activate();

	if (!dartCode?.isActive) {
		await vs.window.showErrorMessage(`${extensionName} was unable to activate the Dart extension.`);
		return;
	}

	const dartCodeExports = dartCode.exports as DartCodeExports;
	const getExtensionApi = dartCodeExports.getExtensionApi;
	if (!getExtensionApi) {
		await vs.window.showErrorMessage(`You require a newer version of the Dart extension to use ${extensionName}`);
		return;
	}

	const dartCodeApi = await getExtensionApi(extensionName);
	context.subscriptions.push(dartCodeApi);
	context.subscriptions.push(new Sidebar(dartCodeApi));
}

export function deactivate() {
	// Cleanup.
}
