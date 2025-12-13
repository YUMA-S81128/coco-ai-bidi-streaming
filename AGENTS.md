# Gemini Live Streaming Agent - AIエージェント向け指示書

> **Note**: このファイルは AI コーディングエージェント向けの指示書です。
> プロジェクトのアーキテクチャ、データモデル、セットアップ手順については [README.md](./README.md) を参照してください。

## 開発原則・コーディング規約

### 全般

- **非推奨の記法:** Python および Flutter に関して、2025 年 10 月末時点で公式に非推奨 (deprecated) となっている記法やライブラリの機能は使用しないこと。
- **AI 駆動開発:** コード生成を依頼する際は、本ドキュメント (`AGENTS.md`) をコンテキストとして参照すること。タスクは小さく、具体的に指示すること。AI が生成したコードは必ずレビューし、本規約に準拠しているか確認すること。
- **最新情報の参照:** 本プロジェクトは最新の技術スタックを採用しているため、調査や実装の際には、Web 検索や公式ドキュメントの最新版を積極的に参照すること。
- **不明な情報の明言:** わからないことや未確認の情報は、必ず「現時点では不明です」「確認できませんでした」と明言します。
- **推測の明示:** 推測を含む場合は、必ず「これは推測ですが、」と前置きします。
- **出典の添付:** 回答には、必ず情報の根拠となる出典（可能な限り一次情報）を添付します。

### Python (Backend / FastAPI)

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

### Flutter (Frontend / Web)

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
  - `setState()` を持つ `StatefulWidget` の使用は、フォームの入力テキストやローカルな UI アニメーションなど、局所的な状態に限定すること。
- **非同期処理:**
  - `FutureProvider` や `StreamProvider` を活用し、`FutureBuilder` / `StreamBuilder` の手動管理を可能な限り避けること。
