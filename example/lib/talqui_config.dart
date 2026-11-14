/// Where the example connects. The defaults are the Talqui demo workspace;
/// replace them with your own ids (app.talqui.chat → Plugins → WebChat →
/// Installation), or pass them when running:
///
///   flutter run --dart-define=TALQUI_TENANT_ID=… --dart-define=TALQUI_CONNECTION_ID=…
const talquiTenantId = String.fromEnvironment('TALQUI_TENANT_ID', defaultValue: 'a0047199-8537-4f7d-bef8-2fae04a7ffd6');
const talquiConnectionId = String.fromEnvironment('TALQUI_CONNECTION_ID', defaultValue: 'a575c54c-4f0e-49e9-87c1-1b80df59e9df');

/// Only for developing the SDK against a local WebChat. Leave unset.
const talquiBaseUrl = String.fromEnvironment('TALQUI_BASE_URL');
