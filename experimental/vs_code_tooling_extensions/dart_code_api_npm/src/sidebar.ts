import * as vs from "vscode";
import * as dc from './dart_code';

export class Sidebar implements vs.Disposable {
	// TODO(dantup): Should this class be provided as a package, or just code inside the sample extension?
	protected readonly disposables: vs.Disposable[] = [];
	private readonly webViewProvider: SidebarWebViewProvider;

	constructor(dartCodeApi: dc.DartCodeApi) {
		const flutterUiUriOverride = process.env.FLUTTER_UI_URL_OVERRIDE;
		const flutterUiUri = flutterUiUriOverride ? vs.Uri.parse(flutterUiUriOverride) : undefined;
		if (!flutterUiUri) {
			throw new Error("Only local dev currently supported!");
		}

		this.disposables.push(this.webViewProvider = new SidebarWebViewProvider(dartCodeApi, flutterUiUri));
		this.disposables.push(vs.window.registerWebviewViewProvider("dartFlutterToolingExtensionSample", this.webViewProvider, { webviewOptions: { retainContextWhenHidden: true } }));
	}

	dispose(): void {
		const toDispose = this.disposables.slice();
		this.disposables.length = 0;
		for (const d of toDispose) {
			try {
				d.dispose();
			} catch (e) {
				console.warn(e);
			}
		}
	}
}

class SidebarWebViewProvider implements vs.WebviewViewProvider, vs.Disposable {
	protected readonly disposables: vs.Disposable[] = [];
	public webviewView: vs.WebviewView | undefined;

	constructor(private readonly dartCodeApi: dc.DartCodeApi, private readonly flutterUiUri: vs.Uri) {
		this.proxyEvent("debug.onSessionStarting", (e) => dartCodeApi.debug.onSessionStarting(e));
		this.proxyEvent("debug.onSessionStarted", (e) => dartCodeApi.debug.onSessionStarted(e));
		this.proxyEvent("debug.onSessionEnded", (e) => dartCodeApi.debug.onSessionEnded(e));
	}

	private proxyEvent(eventName: string, subscribe: (listener: (e: unknown) => unknown) => vs.Disposable) {
		this.disposables.push(subscribe((e) => this.sendMessageToWebView({ event: eventName, params: e })));
	}

	public resolveWebviewView(webviewView: vs.WebviewView, context: vs.WebviewViewResolveContext<unknown>, token: vs.CancellationToken): void | Thenable<void> {
		this.webviewView = webviewView;

		// eslint-disable-next-line @typescript-eslint/no-unsafe-argument, @typescript-eslint/no-explicit-any
		this.disposables.push(webviewView.webview.onDidReceiveMessage((message: unknown) => this.handleMessageFromWebView(message as any)));

		const frameUri = this.flutterUiUri.toString();
		const pageScript = `
		const vscode = acquireVsCodeApi();
		window.addEventListener('message', (message) => {
			const data = message.data;
			if (data.direction === "WEBVIEW_TO_EXTENSION") {
				vscode.postMessage(data.payload);
				return;
			} else if (data.direction === "EXTENSION_TO_WEBVIEW") {
				const extensionUiFrame = document.getElementById('extensionUiFrame');
				extensionUiFrame.contentWindow.postMessage(data.payload, "${frameUri}");
			} else {
				console.warn(\`Unknown message: \${JSON.stringify(data)}\`);
			}
		});
		`;

		webviewView.webview.options = {
			enableScripts: true,
			localResourceRoots: [],
		};
		webviewView.webview.html = `
			<html>
			<head>
			<meta http-equiv="Content-Security-Policy" content="default-src *; script-src 'unsafe-inline'; style-src 'unsafe-inline';">
			<script>${pageScript}</script>
			</head>
			<body><iframe id="extensionUiFrame" src="${frameUri}" frameborder="0" style="position: absolute; top: 0; left: 0; width: 100%; height: 100%"></iframe></body>
			</html>
		`;
		// TODO(dantup): Find a better way to ensure the frame gets our origin URL.
		// TODO(dantup): This might only be happening once, and not after Reload WebViews?
		setTimeout(
			() => void webviewView.webview.postMessage({ direction: 'EXTENSION_TO_WEBVIEW', payload: { method: 'ping' } }),
			5000,
		);
	}

	public async sendMessageToWebView(message: unknown): Promise<boolean | undefined> {
		// TODO(dantup): What when it's not here? Queue?
		return this.webviewView?.webview.postMessage({
			direction: "EXTENSION_TO_WEBVIEW",
			payload: message,
		});
	}

	private async handleMessageFromWebView(message: { id?: number, method?: string, params?: unknown }): Promise<void> {
		const id = message.id;
		const method = message.method;
		const params = message.params;
		if (id && method && params) {
			await this.handleRequestFromWebView(id, method, params);
		}
	}

	private async handleRequestFromWebView(id: number, method: string, params: { command?: string, args?: Array<unknown>, method?: string, params?: unknown }) {
		let result: unknown;
		let error: unknown;
		try {
			switch (method) {
				case "vscode.executeCommand":
					const command = params.command!; // eslint-disable-line @typescript-eslint/no-non-null-assertion
					const args = params.args ?? [];
					result = await vs.commands.executeCommand(command, ...args);
					break;
				case "language.rawRequest":
					// TODO(dantup): Add a way for caller to check whether LSP is available.
					if (this.dartCodeApi.language) {
						const languageMethod = params.method!; // eslint-disable-line @typescript-eslint/no-non-null-assertion
						const languageParams = params.params;
						result = await this.dartCodeApi.language?.rawRequest(languageMethod, languageParams);
					} else {
						error = "Language functionality is not available, perhaps the legacy language server protocol is being used?";
					}
					break;
				default:
					error = `Unknown request "${method}"`;
					break;
			}
		} catch (e: unknown) {
			error = `Failed to handle request "${method}": ${e}`; // eslint-disable-line @typescript-eslint/restrict-template-expressions
		}

		await this.sendMessageToWebView({
			id,
			result,
			error,
		});
	}

	dispose(): void {
		const toDispose = this.disposables.slice();
		this.disposables.length = 0;
		for (const d of toDispose) {
			try {
				d.dispose();
			} catch (e) {
				console.warn(e);
			}
		}
	}
}
