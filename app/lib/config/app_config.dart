/// アプリケーション環境設定。
///
/// ビルド時に `--dart-define` で環境変数を渡すことで、
/// 開発環境と本番環境の設定を切り替える。
///
/// 例: `flutter build web --dart-define=BACKEND_URL=https://your-cloud-run.run.app`
class AppConfig {
  AppConfig._();

  /// バックエンド（Cloud Run）サービスの URL。
  ///
  /// ビルド時に `--dart-define=BACKEND_URL=xxx` で指定可能。
  /// 未指定の場合はローカル開発用のデフォルト値を使用する。
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
