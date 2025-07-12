FROM node:18-alpine

WORKDIR /app

# curlをインストール（ヘルスチェック用）
RUN apk add --no-cache curl

# パッケージファイルをコピー
COPY package*.json ./

# 依存関係をインストール
RUN npm ci --only=production

# ソースコードをコピー
COPY . .

# TypeScriptをコンパイル
RUN npm run build

# twiml.xmlファイルをdistディレクトリにコピー
RUN cp src/twiml.xml dist/twiml.xml

# ポートを公開
EXPOSE 8081

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8081/public-url || exit 1

# アプリケーションを起動
CMD ["node", "dist/server.js"] 