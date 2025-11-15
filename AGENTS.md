# Gemini Live Streaming Agent プロジェクト仕様

## 1. 概要

本プロジェクトは、Flutter (Web) と Python (FastAPI, ADK) を用い、リアルタイムの音声ストリーミング対話と、会話コンテキストに応じた画像生成が可能な Web アプリケーションを構築することを目的とする。

アーキテクチャは、Vertex AI Agent Engine 上で稼働する ADK エージェントを中核とし、Firebase Authentication による認証、Cloud Functions を介した一時トークンによる安全な WebSocket 接続、および Firestore と Cloud Storage を活用した非同期の画像生成ジョブ管理を特徴とする。

## 2. アーキテクチャ概要

- **クライアント:** Flutter (Web)
- **認証:** Firebase Authentication
- **バックエンド (ADK Agent):** Python (FastAPI, ADK)
- **バックエンド (トークン発行):** Python (Cloud Functions for Firebase)
- **リアルタイム通信:** WebSocket
- **AI モデル:** Gemini Live API (双方向ストリーミング)
- **データベース/状態管理:** Cloud Firestore
- **ストレージ:** Cloud Storage for Firebase (生成画像)
- **デプロイ先:**
  - **フロントエンド:** Firebase Hosting
  - **ADK エージェント:** Vertex AI Agent Engine
  - **トークン発行関数:** Cloud Functions for Firebase

## 3. 主要な技術スタック

- **フロントエンド:** Flutter (Web)
  - `firebase_core`, `firebase_auth`: Firebase 連携、認証
  - `cloud_firestore`: Firestore へのリアルタイム接続
  - `web_socket_channel`: WebSocket 通信管理
  - `mic_stream` / `flutter_sound`: (Web対応) マイクからの生音声ストリーム取得
  - `audioplayers`: (Web対応) サーバーからの応答音声ストリームの再生
- **バックエンド (ADK Agent):** Python (FastAPI)
  - `fastapi`: API サーバー構築
  - `websockets`: WebSocket エンドポイントの実装
  - `google-adk`: Gemini Live API との接続を管理
  - `firebase-admin`: Firestore, Auth, Storage へのアクセス
- **認証:** Firebase Authentication
- **データベース:** Cloud Firestore
- **ストレージ:** Cloud Storage for Firebase
- **デプロイ:**
  - **フロントエンド:** Firebase Hosting
  - **ADK エージェント:** Vertex AI Agent Engine
  - **トークン発行エンドポイント:** Cloud Functions for Firebase (2nd Gen, Python)

## 4. 接続シーケンスとアーキテクチャ (一時トークン方式)

フロントエンドからバックエンドエージェントへの接続は、セキュリティとパフォーマンスを両立するため、**一時トークン (ephemeral token)** を利用したアーキテクチャを推奨する。

この方式では、フロントエンドは認証用の短命なトークンを使って、Vertex AI Agent Engine 上で稼働する ADK エージェントの WebSocket エンドポイントに直接接続する。エージェントがフロントエンドと Gemini Live API との間のストリーミングを中継する。

### 4.1. 接続・ストリーミングフロー

1.  **[トリガー]** ユーザーが対話開始のアクション（例: マイクボタンを押す）を行う。
2.  **[トークン要求]** フロントエンドは、**Cloud Functions for Firebase (Python) で構築したトークン発行用 HTTP エンドポイント**に対し、一時トークンの発行をリクエストする。この際、Firebase Auth の ID トークンをヘッダーに含め、リクエスト元が認証済みユーザーであることを証明する。
3.  **[トークン生成]** Cloud Function は、ID トークンを検証後、Vertex AI Agent Engine への接続を認証するための短命な一時トークンを生成し、フロントエンドに返却する。
4.  **[WebSocket 接続]** フロントエンドは、受け取った一時トークンを使い、**Vertex AI Agent Engine 上で公開されている ADK エージェントの WebSocket エンドポイント**へ接続を確立する。
5.  **[音声送信]** フロントエンドは、マイクから取得した音声チャンクを WebSocket 経由で ADK エージェントへ継続的に送信する。
6.  **[ストリーム中継]** ADK エージェントは、フロントエンドから受信した音声チャンクを **Gemini Live API** に転送する。同時に、Gemini Live API から返却される応答音声チャンクをフロントエンドに転送する。この間の処理は ADK が抽象化する。
7.  **[音声再生]** フロントエンドは、ADK エージェントから受信した応答音声チャンクをバッファし、即座にスピーカーで再生する。
8.  **[接続終了]** ユーザーが「トーク終了ボタン」を押下するか、会話内の終了意図を ADK エージェントが検知すると、エージェントは Gemini Live API とのセッションを終了し、WebSocket 接続を正常に閉じる。

### 4.2. 一時トークンのライフサイクルと注意点

-   **発行のタイミング:** 一時トークンは、新しい WebSocket 接続を開始できる有効期限が**非常に短い**（デフォルトで1分）。そのため、**アプリのログイン時ではなく、WebSocket 接続を確立する直前にリクエストする**必要がある。
-   **有効期限:**
    -   **新規セッション開始期限 (`newSessionExpireTime`):** デフォルト1分。この時間内に接続を開始しなければトークンは無効になる。
    -   **接続持続期限 (`expireTime`):** デフォルト30分。一度確立した接続が持続できる時間。
-   **再接続処理:** 接続持続期限が切れた場合や、ネットワークの不安定さにより接続が切断された場合に備え、フロントエンド側には**再度一時トークンを取得して再接続を試みるロジックの実装が必須**となる。

この方式により、永続的な API キーやサービスアカウントキーをフロントエンドに露出させることなく、低レイテンシなリアルタイム対話を実現できる。

## 5. シーケンス: 画像生成 (Firestore, Cloud Storage 経緯)

1.  **[Gemini Live]** 会話の中で、Gemini が「（絵を描く）必要がある」と判断する。(例: 「ライオンさんの絵を描くね！」と発話する)
2.  **[ADK Agent]** (ADK の機能を利用し) Gemini のその判断（または特定のツールコール）を検知する。
3.  **[ADK Agent]** Gemini が生成した画像生成用プロンプトを取得する。
4.  **[ADK Agent]** Firestore の `jobs` コレクションに新しいドキュメントを作成する。
    - `status`: "pending"
    - `prompt`: "A friendly lion for a child"
    - `createdAt`: Timestamp
5.  **[Flutter]** Firestore の該当コレクションを `snapshots()` でリアルタイム監視（`StreamBuilder` など）している。
6.  **[Flutter]** `status: "pending"` の新しいジョブを検知し、UI に「絵を描き始めたよ...」などのインジケーターを表示する。
7.  **(別途のバックエンドプロセス or Cloud Function)** Firestore の `jobs` コレクションの `onCreate` トリガーが発火する。
8.  **[Backend Process]** 画像生成 API (Imagen 等) を呼び出し、生成された画像を **Cloud Storage for Firebase** にアップロードする。
9.  **[Backend Process]** アップロードした画像の**ダウンロードURL**を生成し、`jobs` ドキュメントを更新する。
    - `status`: "completed"
    - `downloadUrl`: "https://firebasestorage.googleapis.com/..." (永続的な公開 URL)
10. **[Flutter]** `status: "completed"` への変更を検知し、UI 上のインジケーターを `Image.network(job.downloadUrl)` を使って生成された画像に差し替える。

## 6. データモデル (Firestore)

### 概要
Firestoreのデータモデルは、将来的な機能拡張性とクエリの効率を考慮し、正規化された構造を採用します。ユーザー、会話セッション、メッセージ、ツール、非同期ジョブをそれぞれ独立したコレクションで管理します。

### 1. `users` コレクション
Firebase Authenticationで認証されたユーザーの情報を保持します。ドキュメントIDはFirebase AuthのUIDとします。

```
/users/{user_id}
  - displayName: string      // 表示名
  - createdAt: timestamp     // アカウント作成日時
```

### 2. `chats` コレクション
個々の会話セッションのメタデータを保持します。

```
/chats/{chat_id}
  - userId: string           // 所有者のID (users/{user_id}への参照)
  - title: string            // AIによって生成された会話の要約タイトル
  - createdAt: timestamp     // 会話開始日時
  - updatedAt: timestamp     // 最終更新日時
```

### 3. `messages` サブコレクション
特定の会話に含まれる全てのメッセージを時系列で保持します。

```
/chats/{chat_id}/messages/{message_id}
  - role: string             // "user" | "model" | "tool" (発言者)
  - content: string          // メッセージ内容 or ツールの実行結果
  - toolCalls: array | null  // (role: "model" の場合) モデルが呼び出したツールの情報
    - toolName: string       // 呼び出したツール名
    - jobId: string          // 非同期ジョブのID (image_jobs/{job_id}への参照)
  - createdAt: timestamp     // 送信日時
```

### 4. `image_jobs` コレクション
画像生成のような非同期で実行されるジョブの状態を管理します。フロントエンドはこれを監視してリアルタイムにUIを更新します。

```
/image_jobs/{job_id}
  - userId: string           // ジョブを開始したユーザー
  - chatId: string           // 関連する会話
  - messageId: string        // 関連するメッセージ
  - prompt: string           // 画像生成に使用されたプロンプト
  - status: string           // "pending" | "processing" | "completed" | "failed"
  - imageUrl: string | null  // 生成が完了した画像のURL
  - error: string | null     // 失敗した場合のエラーメッセージ
  - createdAt: timestamp     // ジョブ作成日時
  - updatedAt: timestamp     // ジョブ状態の最終更新日時
```

## 7. 開発原則・コーディング規約

### 7.1. 全般

- **非推奨の記法:** Python および Flutter に関して、2025年10月末時点で公式に非推奨 (deprecated) となっている記法やライブラリの機能は使用しないこと。
- **AI 駆動開発:** コード生成を依頼する際は、本ドキュメント (`AGENTS.md`) をコンテキストとして参照すること。タスクは小さく、具体的に指示すること。AI が生成したコードは必ずレビューし、本規約に準拠しているか確認すること。
- **最新情報の参照:** 本プロジェクトは最新の技術スタックを採用しているため、調査や実装の際には、Web検索や公式ドキュメントの最新版を積極的に参照すること。
- **不明な情報の明言:** わからないことや未確認の情報は、必ず「現時点では不明です」「確認できませんでした」と明言します。
- **推測の明示:** 推測を含む場合は、必ず「これは推測ですが、」と前置きします。
- **出典の添付:** 回答には、必ず情報の根拠となる出典（可能な限り一次情報）を添付します。

### 7.2. Python (Backend / FastAPI)

- **前提バージョン:** **Python 3.13 以降**を前提とする。
- **パッケージ管理:** Python のパッケージ管理には、Astral 社が開発する高速なパッケージマネージャー [`uv`](https://github.com/astral-sh/uv) を使用すること。
- **スタイルガイド:** [Google Python スタイルガイド](https://google.github.io/styleguide/pyguide.html) および [PEP 8](https://peps.python.org/pep-0008/) に準拠すること。
- **型ヒント (PEP 585, 604, 695):**
  - **全ての**関数定義（引数、戻り値）および主要な変数宣言には、型ヒントを**必須**とする。
  - `typing.List`, `typing.Dict`, `typing.Tuple` は**使用禁止**とする。代わりに `list[str]`, `dict[str, int]`, `tuple[int, ...]` のような組み込みジェネリクス (PEP 585) を使用すること。
  - `typing.Union` および `typing.Optional` は**使用禁止**とする。代わりに `str | int` や `str | None` のような `|` (Union 演算子, PEP 604) を使用すること。
  - ジェネリック関数やクラスの定義には、**PEP 695** 構文を**最優先で使用**すること。(例: `def my_func[T](arg: T) -> T:` や `class MyClass[T]:`)。
  - `typing.TypeVar` の使用は、PEP 695 で対応できない高度なケース（`TypeVarTuple` や `ParamSpec` など）に限定すること。
- **非同期処理 (Async/Await):**
  - I/O 処理（Gemini API へのリクエスト、Firestore へのアクセス、WebSocket 通信）は、**必ず** `async def` と `await` を使用した非ブロッキング処理とすること。
  - CPU バウンドな重い計算（万が一発生する場合）は、`async def` 内で直接実行せず、FastAPI の `run_in_threadpool` などを介して別スレッドで実行すること。
  - `time.sleep()` のようなブロッキング呼び出しは `async def` 内で**絶対に使用しない**こと。代わりに `await asyncio.sleep()` を使用すること。
- **FastAPI:**
  - データモデル（リクエストボディ、レスポンスモデル）には Pydantic の `BaseModel` を使用し、型検証を徹底すること。
  - ビジネスロジックをルート関数 (`@app.post(...)`) 内に直接記述せず、`services` や `use_cases` などの別レイヤーに分離すること。

### 7.3. Flutter (Frontend / Web)

- **スタイルガイド:** [Effective Dart](https://dart.dev/guides/language/effective-dart) の規約に準拠すること。
- **型指定:**
  - **ローカル変数**では、[Effective Dart の推奨](https://dart.dev/guides/language/effective-dart/language/variables#use-var-and-final-for-local-variables)に従い `var` や `final` を使用する。
  - ただし、型が推論しにくい場合（例: `var` では `dynamic` になってしまう場合）や、**クラスのフィールド（状態）**を定義する場合は、**必ず明示的な型**（`String`, `int`, `List<Job>`）を使用すること。
- **イミュータビリティ (Immutability):**
  - データモデル（`Job` など）は、`freezed` パッケージを利用し、**イミュータブル（不変）**なクラスとして定義すること。
  - `const` キーワードを最大限活用すること。特に `StatelessWidget` 内の `Padding` や `SizedBox` などの静的なウィジェットには `const` を付与し、不要なリビルドを徹底的に避けること。
- **ウィジェット:**
  - `build` メソッドは純粋（ロジックを含まない）に保つこと。
  - ウィジェットツリーが深くなる場合は、`builder` やメソッド (`_buildMyWidget()`) に切り出すのではなく、**新しい `StatelessWidget` / `ConsumerWidget` としてクラスを分離**すること。
  - `ListView.builder` や `GridView.builder` を積極的に使用し、画面外のウィジェットをビルドしないこと。
- **状態管理:**
  - 状態管理には **Riverpod** を使用し、ウィジェットツリーからビジネスロジックを分離すること。
  - `setState()` を持つ `StatefulWidget` の使用は、フォームの入力テキストやローカルなUIアニメーションなど、局所的な状態に限定すること。
- **非同期処理:**
  - `FutureProvider` や `StreamProvider` を活用し、`FutureBuilder` / `StreamBuilder` の手動管理を可能な限り避けること。

## 8. 参考情報

- **ADK Bidi-streaming (live) Overview:**
  - [https://google.github.io/adk-docs/streaming/](https://google.github.io/adk-docs/streaming/)
  - ADKにおける双方向ストリーミング機能の全体像とアーキテクチャに関する公式ドキュメント。

- **Streaming Quickstart:**
  - [https://google.github.io/adk-docs/get-started/streaming/quickstart-streaming/](https://google.github.io/adk-docs/get-started/streaming/quickstart-streaming/)
  - ADKのストリーミング機能を試すための公式クイックスタートガイド。

- **Custom Streaming with WebSocket:**
  - [https://google.github.io/adk-docs/streaming/custom-streaming-ws/](https://google.github.io/adk-docs/streaming/custom-streaming-ws/)
  - カスタムWebSocketサーバーを実装してADKのストリーミング機能を利用する方法についての詳細なガイド。本プロジェクトのアーキテクチャに密接に関連する。

