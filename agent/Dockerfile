# -----------------------------
# Builder stage
# -----------------------------
# 公式の uv 搭載イメージを使用 (Python 3.13 ベース)
# これにより、uv のインストール手順を省略でき、最適化された設定を利用できます
FROM ghcr.io/astral-sh/uv:0.9.16-python3.13-trixie-slim AS builder

# 1. 依存関係の定義ファイルをコピー
# キャッシュを効かせるため、ソースコードより先にこれらをコピーします
WORKDIR /app
COPY pyproject.toml uv.lock ./

# 2. 依存ライブラリのインストール
# --frozen: ロックファイル (uv.lock) に完全に準拠してインストール
# --no-install-project: プロジェクト自体のコードはまだ入れず、依存パッケージのみインストール (キャッシュ効率化)
# --no-dev: 本番用なので開発用依存は含めない
RUN uv sync --frozen --no-install-project --no-dev

# 3. ソースコードのコピー
COPY . .

# 4. プロジェクトのインストール
# ソースが入った状態で再度 sync を実行し、プロジェクト自体をインストールします
# 既存の依存関係はキャッシュされているため高速に完了します
RUN uv sync --frozen --no-dev

# -----------------------------
# Final stage
# -----------------------------
# 実行用イメージも同じ uv 公式イメージを使用
FROM ghcr.io/astral-sh/uv:0.9.16-python3.13-trixie-slim AS final

# 1. ランタイムの設定
# PYTHONUNBUFFERED: ログをバッファリングせず即時出力させる (コンテナログ用)
# UV_COMPILE_BYTECODE: インポート速度向上のためバイトコンパイルを有効化
# PATH: .venv/bin を優先パスに追加し、venv 内のコマンド (uvicorn 等) を直接実行可能にする
ENV PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    PATH="/app/.venv/bin:$PATH"

# 2. 作業ディレクトリの設定
WORKDIR /app

# 3. OS レベルの依存パッケージのインストール
# ca-certificates: HTTPS 通信に必要。最小限の構成にします
# uv イメージは Debian ベースなので apt-get が利用可能です
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*

# 4. 非 root ユーザーの作成と設定
# セキュリティ向上のため、アプリケーション専用のユーザー (appuser) で実行します
RUN groupadd --system --gid 1001 appgroup && \
    useradd --system --uid 1001 --gid appgroup appuser

# 5. ビルド成果物のコピー
# builder ステージで作成した仮想環境 (.venv) を丸ごとコピーします
# 依存ライブラリとインストールされたプロジェクトが含まれています
COPY --from=builder --chown=appuser:appgroup /app/.venv /app/.venv

# 6. ソースコードのコピー
# アプリケーションのコードを配置します (.venv 内の参照先として必要になる場合があるため)
COPY --chown=appuser:appgroup . .

# 7. 実行ユーザーの切り替え
USER appuser

# 8. アプリケーションの起動
# 環境変数 PORT (デフォルト 8080) で待機
# exec uvicorn ... とすることで、PID 1 として起動しシグナルハンドリングを正常化します
ENTRYPOINT ["sh", "-c", "exec uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080} --proxy-headers"]
