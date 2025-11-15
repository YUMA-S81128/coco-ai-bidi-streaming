# Gemini Live Streaming App

## 1. 概要

本アプリケーションは、[Gemini Live Streaming Agent プロジェクト](../AGENTS.md)のフロントエンド部分です。
Flutter (Web) を用いて構築されており、リアルタイムの音声ストリーミング対話と、会話コンテキストに応じた画像生成が可能な Web アプリケーションを提供します。

## 2. 主な機能

-   **リアルタイム音声対話:**
    -   マイクから取得した音声をリアルタイムでバックエンドのADKエージェントにストリーミングします。
    -   ADKエージェントから返される応答音声を即座に再生し、低遅延な会話体験を実現します。
-   **画像生成と表示:**
    -   会話の流れに応じてバックエンドが開始する画像生成ジョブの状態をリアルタイムに監視します。
    -   生成が完了した画像を画面上に表示します。
-   **認証:**
    -   Firebase Authentication を利用してユーザー認証を行います。

## 3. アーキテクチャと技術スタック

-   **フレームワーク:** Flutter (Web)
-   **状態管理:** [Riverpod](https://riverpod.dev/)
-   **データモデル:** [freezed](https://pub.dev/packages/freezed) を利用したイミュータブルなクラス
-   **リアルタイム通信:**
    -   `web_socket_channel` を使用し、バックエンドのADKエージェントとWebSocketで接続します。
    -   接続には、Cloud Functionsが発行する一時トークンを利用します。
-   **データベース:** `cloud_firestore` を介してFirestoreに接続し、画像生成ジョブの状態をリアルタイムで監視します。
-   **認証:** `firebase_auth` を利用したFirebase Authentication
-   **音声入出力:**
    -   マイク入力: `mic_stream` や `flutter_sound` などのWeb対応パッケージを利用
    -   音声出力: `audioplayers` などのWeb対応パッケージを利用

詳細なアーキテクチャやシーケンス図については、プロジェクトルートの [`AGENTS.md`](../AGENTS.md) を参照してください。

## 4. 開発

### セットアップ

Flutterプロジェクトの標準的な手順に従ってください。

```bash
flutter pub get
```

### 実行

Web開発サーバーを起動します。

```bash
flutter run -d chrome
```

### コーディング規約

開発を進める際は、プロジェクトルートの [`AGENTS.md`](../AGENTS.md) に記載されている以下の規約に従ってください。

-   **Effective Dart** の遵守
-   **Riverpod** を用いた状態管理
-   **freezed** を用いたイミュータブルなデータモデルの定義
-   UIコンポーネントの適切な分離
-   `const` キーワードの最大限の活用