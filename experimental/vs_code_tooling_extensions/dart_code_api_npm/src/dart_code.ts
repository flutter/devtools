import * as vs from "vscode";

// TODO(dantup): Should this be published from Dart-Code? It needs to be kept in-sync with the
//  actual Dart-Code exported API (and Dart-Code needs to reference it to ensure it's implemented
//  correctly).

/**
 * Represents the `exports` from the Dart extension.
 *
 * Only types and interfaces reachable from here are considered public API. Accessing
 * items included in the Dart extension exports that are not defined here are private
 * API and can change/break without warning.
 */
export interface DartCodeExports {
	/**
	 * Creates an instance of DartCodeApi to use.
	 *
	 * @param extensionName: The name of the extension calling this API. This may be included
	 *        in messages sent to other tools (such as the LSP server) so that it shows up in
	 *        traffic logs to aid debugging.
	 */
	getExtensionApi?(this: void, extensionName: string): Promise<DartCodeApi>;
}

export interface DartCodeApi extends vs.Disposable {
	readonly debug: DartCodeDebugApi;
	readonly language: DartCodeLanguageApi | undefined;
}

export interface DartCodeDebugApi {
	onSessionStarting(listener: (e: DartDebugSessionStartingEvent) => unknown): vs.Disposable;
	onSessionStarted(listener: (e: DartDebugSessionStartedEvent) => unknown): vs.Disposable;
	onSessionEnded(listener: (e: DartDebugSessionEndedEvent) => unknown): vs.Disposable;
}

export interface DartCodeLanguageApi {
	rawRequest(method: string, params: unknown): Promise<unknown>;
}

export interface DartDebugSessionStartingEvent {
	readonly id: string;
	readonly configuration: vs.DebugConfiguration;
}
export interface DartDebugSessionStartedEvent {
	readonly id: string;
	readonly vmService: string | undefined;
}
export interface DartDebugSessionEndedEvent {
	readonly id: string;
}
