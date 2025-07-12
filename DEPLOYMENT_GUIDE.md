# OpenAI Twilio Demo AWS本番環境構築ガイド

このガイドでは、OpenAI Realtime APIとTwilioを組み合わせた音声通話アシスタントをAWS環境に本番構築する手順を詳しく説明します。

## 📋 前提条件

### 必要なアカウントとサービス
- **AWSアカウント**: 有効なAWSアカウント
- **Twilioアカウント**: 音声通話用のアカウント（https://console.twilio.com/）
- **OpenAI APIキー**: Realtime API用のAPIキー
- **GitHubアカウント**: フロントエンド用のリポジトリ

### 必要なツール
- AWS CLI（最新版）
- Docker
- Git

### コスト見積もり（月額）
- **ECS Fargate**: $15-30（WebSocketサーバーのみ）
- **Application Load Balancer**: $20-30
- **CloudWatch**: $5-10
- **Amplify**: $1-5（フロントエンド）
- **Twilio電話番号**: $1.15
- **データ転送**: $5-15
- **合計**: $45-90/月

## 🚀 デプロイ手順

### ステップ1: 環境準備

#### 1.1 AWS CLIの設定
```bash
# AWS CLIのインストール（Ubuntuの場合）
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# AWS認証情報の設定
aws configure
# AWS Access Key ID: [あなたのアクセスキー]
# AWS Secret Access Key: [あなたのシークレットキー]
# Default region name: ap-northeast-1
# Default output format: json
```

#### 1.2 プロジェクトの準備
```bash
# プロジェクトをクローン
git clone https://github.com/your-repo/openai-realtime-twilio-demo.git
cd openai-realtime-twilio-demo

# WebSocketサーバーの依存関係をインストール
cd websocket-server && npm install
cd ..
```

### ステップ2: フロントエンド用リポジトリの作成

#### 2.1 フロントエンド専用リポジトリの作成
```bash
# 新しいディレクトリを作成
mkdir twilio-realtime-frontend
cd twilio-realtime-frontend

# webappの内容をコピー
cp -r ../openai-realtime-twilio-demo/webapp/* .

# Gitリポジトリを初期化
git init
git add .
git commit -m "Initial commit: Twilio Realtime Frontend"
git branch -M main
```

#### 2.2 GitHubでリポジトリを作成
1. GitHub.comにアクセス
2. 右上の「+」ボタンをクリック
3. 「New repository」を選択
4. リポジトリ名: `twilio-realtime-frontend`
5. 説明: `OpenAI Realtime Twilio Demo Frontend`
6. Public/Privateを選択
7. 「Create repository」をクリック

#### 2.3 リポジトリにプッシュ
```bash
# リモートリポジトリを追加（YOUR_USERNAMEを実際のユーザー名に置き換え）
git remote add origin https://github.com/YOUR_USERNAME/twilio-realtime-frontend.git

# メインブランチをプッシュ
git push -u origin main
```

### ステップ3: 初期セットアップ

#### 3.1 初期セットアップスクリプトの実行
```bash
# 元のプロジェクトディレクトリに戻る
cd ../openai-realtime-twilio-demo

# 初期セットアップを実行
./setup.sh
```

このスクリプトは以下を実行します：
- ECSクラスターの作成（WebSocketサーバー用）
- タスク実行ロールの作成
- ECRリポジトリの作成
- CloudWatchロググループの作成
- VPCスタックのデプロイ
- WAFスタックのデプロイ

#### 3.2 環境変数の設定
```bash
# OpenAI APIキー
aws ssm put-parameter \
    --name "/openai-twilio-demo/OPENAI_API_KEY" \
    --value "your-openai-api-key" \
    --type "SecureString"

# Twilio認証情報
aws ssm put-parameter \
    --name "/openai-twilio-demo/TWILIO_ACCOUNT_SID" \
    --value "your-twilio-account-sid" \
    --type "SecureString"

aws ssm put-parameter \
    --name "/openai-twilio-demo/TWILIO_AUTH_TOKEN" \
    --value "your-twilio-auth-token" \
    --type "SecureString"

# カスタムドメインがある場合
aws ssm put-parameter \
    --name "/openai-twilio-demo/DOMAIN_NAME" \
    --value "your-domain.com" \
    --type "String"
```

### ステップ4: SSL証明書の設定（サブドメイン）
Route53 > ホストゾーン > `任意のレコード` > レコードを作成
レコード名:任意
レコードタイプ:A - IPv4
値:127.0.0.1(一旦仮置き。後でALBのDNSに変更する)

#### 4.1 SSL証明書のリクエスト
```bash
# ドメイン名を取得
DOMAIN_NAME=$(aws ssm get-parameter --name "/openai-twilio-demo/DOMAIN_NAME" --query 'Parameter.Value' --output text)

# SSL証明書をリクエスト
aws acm request-certificate \
    --domain-name $DOMAIN_NAME \
    --subject-alternative-names *.$DOMAIN_NAME \
    --validation-method DNS

# 証明書のARNを取得
CERTIFICATE_ARN=$(aws acm list-certificates --query "CertificateSummaryList[?DomainName=='$DOMAIN_NAME'].CertificateArn" --output text)
```

#### 4.2 DNS検証の完了
1. AWS Certificate Managerコンソールで証明書の詳細を確認
2. Route53でレコードを作成をクリック
3. DNS検証用のCNAMEレコードをDNSプロバイダーに追加
4. 検証が完了するまで待機（通常5-10分）

### ステップ5: インフラのデプロイ

#### 5.1 インフラデプロイスクリプトの実行
```bash
# インフラをデプロイ
./deploy-infrastructure.sh
```

このスクリプトは以下を実行します：
- ALBスタックのデプロイ（WebSocketサーバー用）
- タスク定義の登録
- ECSサービスの作成（WebSocketサーバーのみ）
- CloudWatchアラームの設定

### Dockerインストール
※ UbuntuにDockerが入っていない場合はインストール
```sh
./docker-install.sh
```
```sh
docker --version
```

### ステップ6: Amplifyでのフロントエンドデプロイ

#### 6.1 Amplifyアプリの作成
1. **AWS Amplifyコンソールにアクセス**
2. **「New app」→「Host web app」をクリック**
3. **GitHubを選択してリポジトリを接続**
4. **`twilio-realtime-frontend`リポジトリを選択**
5. **ブランチ: `main`を選択**
6. **「Next」をクリック**
7. **ビルド設定は自動検出されるはず**
8. **「Save and deploy」をクリック**

#### 6.2 環境変数の設定
Amplifyコンソールで以下の環境変数を設定：

- **キー**: `NEXT_PUBLIC_WEBSOCKET_URL`
- **値**: `wss://[ALB_DNS]`（ALBのDNS名を後で設定）

#### 6.3 ALBのDNS名を取得して環境変数を更新
```bash
# ALBのDNS名を取得
ALB_DNS=$(aws cloudformation describe-stacks --stack-name openai-twilio-alb --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' --output text)

echo "WebSocket URL: wss://$ALB_DNS"
```

Amplifyコンソールで環境変数を更新：
- `NEXT_PUBLIC_WEBSOCKET_URL`: `wss://$ALB_DNS`

### ステップ7: Twilioの設定

#### 7.1 Twilioアカウントの準備
1. **Twilioアカウントの作成**: https://console.twilio.com/ でアカウントを作成
2. **電話番号の取得**: 音声通話可能な電話番号を取得（約$1.15/月）
3. **認証情報の取得**: Account SIDとAuth Tokenを取得

#### 7.2 Twilio Webhookの設定
```bash
# ALBのDNS名を取得
ALB_DNS=$(aws cloudformation describe-stacks --stack-name openai-twilio-alb --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' --output text)
```

下記出力しtwilioのWebhookに登録
```sh
echo "Twilio Webhook URL: https://$ALB_DNS/twiml"
```

**Twilioコンソールでの設定手順:**
1. Twilioコンソールにログイン
2. Phone Numbers > Manage > Active numbers に移動
3. 取得した電話番号をクリック
4. Voice Configuration セクションで以下を設定:
   - **Webhook URL**: `https://[ALB_DNS]/twiml`
   - **HTTP Method**: `GET`

### カスタムドメインの修正
Route53で作成したサブドメインを修正 > エイリアスをON
トラフィックのルーティング先:Application Load Blancer と Clasic Load Blancer
リージョン:ap-northeast-1
作成したロードバランサーを選択
ロードバランサーのDNSは下記で確認できる
```sh
aws cloudformation describe-stacks --stack-name openai-twilio-alb --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' --output text
```

### ステップ8: WebSocketサーバーのデプロイ

#### 8.1 WebSocketサーバーデプロイスクリプトの実行
```bash
# WebSocketサーバーのみをデプロイ
./deploy-websocket.sh
```

このスクリプトは以下を実行します：
- Dockerイメージのビルド
- ECRへのプッシュ
- タスク定義の更新
- サービスの更新

### ステップ9: 動作確認

#### 9.1 アプリケーションの確認
```bash
# ALBのDNS名を取得
ALB_DNS=$(aws cloudformation describe-stacks --stack-name openai-twilio-alb --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' --output text)

echo "WebSocketサーバーURL: https://$ALB_DNS"
echo "フロントエンドURL: [Amplifyで提供されるURL]"
```

#### 9.2 ヘルスチェック
```bash
# WebSocketサーバーのヘルスチェック
curl https://$ALB_DNS/public-url

# Amplifyアプリのヘルスチェック
curl [Amplify URL]/api/health
```

#### 9.3 音声通話のテスト
1. Twilioで取得した電話番号に電話をかける
2. AIアシスタントとの会話をテスト
3. Amplifyアプリでトランスクリプトを確認

## 🔧 運用とメンテナンス

### ログの確認
```bash
# WebSocketサーバーのログ
aws logs tail /ecs/websocket-server --follow

# Amplifyアプリのログ（Amplifyコンソールで確認）
```

### メトリクスの確認
```bash
# ECSサービスの状態確認
aws ecs describe-services --cluster openai-twilio-demo --services websocket-server

# CloudWatchメトリクスの確認
aws cloudwatch get-metric-statistics \
    --namespace AWS/ECS \
    --metric-name CPUUtilization \
    --dimensions Name=ServiceName,Value=websocket-server Name=ClusterName,Value=openai-twilio-demo \
    --start-time $(date -d '1 hour ago' --iso-8601=seconds) \
    --end-time $(date --iso-8601=seconds) \
    --period 300 \
    --statistics Average
```

### スケーリング
```bash
# WebSocketサーバーのスケール
aws ecs update-service \
    --cluster openai-twilio-demo \
    --service websocket-server \
    --desired-count 3
```

## 🛡️ セキュリティ

### セキュリティグループの確認
```bash
# セキュリティグループの詳細確認
SECURITY_GROUP_ID=$(aws cloudformation describe-stacks --stack-name openai-twilio-vpc --query 'Stacks[0].Outputs[?OutputKey==`SecurityGroupId`].OutputValue' --output text)
aws ec2 describe-security-groups --group-ids $SECURITY_GROUP_ID
```

### WAFルールの確認
```bash
# WAF Web ACLの詳細確認
aws wafv2 get-web-acl --name production-web-acl --scope REGIONAL
```

## 📊 モニタリング

### CloudWatchダッシュボード
1. AWS CloudWatchコンソールにアクセス
2. Dashboards > Create dashboard
3. `aws/cloudwatch-dashboard.json`の内容をインポート

### アラームの設定
```bash
# SNS通知用のメールアドレスを更新
aws cloudformation update-stack \
    --stack-name openai-twilio-alarms \
    --template-body file://aws/cloudwatch-alarms.yaml \
    --parameters \
        ParameterKey=Environment,ParameterValue=production \
        ParameterKey=SNSNotificationEmail,ParameterValue=your-email@example.com \
    --capabilities CAPABILITY_IAM
```

## 🧹 クリーンアップ

### リソースの削除
```bash
# ECSサービスの削除
aws ecs update-service --cluster openai-twilio-demo --service websocket-server --desired-count 0
aws ecs delete-service --cluster openai-twilio-demo --service websocket-server

# CloudFormationスタックの削除
aws cloudformation delete-stack --stack-name openai-twilio-alarms
aws cloudformation delete-stack --stack-name openai-twilio-alb
aws cloudformation delete-stack --stack-name openai-twilio-waf
aws cloudformation delete-stack --stack-name openai-twilio-vpc

# ECRリポジトリの削除
aws ecr delete-repository --repository-name websocket-server --force

# ECSクラスターの削除
aws ecs delete-cluster --cluster openai-twilio-demo

# パラメータの削除
aws ssm delete-parameter --name "/openai-twilio-demo/OPENAI_API_KEY"
aws ssm delete-parameter --name "/openai-twilio-demo/TWILIO_ACCOUNT_SID"
aws ssm delete-parameter --name "/openai-twilio-demo/TWILIO_AUTH_TOKEN"
aws ssm delete-parameter --name "/openai-twilio-demo/PUBLIC_URL"
aws ssm delete-parameter --name "/openai-twilio-demo/DOMAIN_NAME"

# Amplifyアプリの削除（Amplifyコンソールで手動削除）
```

## 🆘 トラブルシューティング

### よくある問題と解決方法

#### 1. ECSタスクが起動しない
```bash
# タスクの詳細を確認
aws ecs describe-tasks --cluster openai-twilio-demo --tasks $(aws ecs list-tasks --cluster openai-twilio-demo --service-name websocket-server --query 'taskArns' --output text)
```

#### 2. ヘルスチェックが失敗する
```bash
# ターゲットグループのヘルス状態を確認
aws elbv2 describe-target-health --target-group-arn $(aws cloudformation describe-stacks --stack-name openai-twilio-alb --query 'Stacks[0].Outputs[?OutputKey==`TargetGroupWebSocketArn`].OutputValue' --output text)
```

#### 3. Twilio Webhookが応答しない
```bash
# ALBのアクセスログを確認
aws logs tail /aws/applicationloadbalancer/openai-twilio-demo-alb-access-logs-ACCOUNT_ID --follow
```

#### 4. 環境変数が読み込まれない
```bash
# パラメータの値を確認
aws ssm get-parameter --name "/openai-twilio-demo/OPENAI_API_KEY" --with-decryption
```

#### 5. Amplifyアプリがビルドに失敗する
- Amplifyコンソールでビルドログを確認
- 環境変数が正しく設定されているか確認
- `amplify.yml`の設定を確認

## 📞 サポート

問題が発生した場合は、以下を確認してください：

1. **CloudWatchログ**: WebSocketサーバーのログでエラーを確認
2. **ECSイベント**: タスクの起動・停止イベントを確認
3. **ALBアクセスログ**: リクエスト・レスポンスを確認
4. **CloudWatchメトリクス**: パフォーマンス指標を確認
5. **Amplifyビルドログ**: フロントエンドのビルドエラーを確認

## 📚 参考資料

- [AWS ECS ドキュメント](https://docs.aws.amazon.com/ecs/)
- [AWS Amplify ドキュメント](https://docs.aws.amazon.com/amplify/)
- [Twilio ドキュメント](https://www.twilio.com/docs)
- [OpenAI API ドキュメント](https://platform.openai.com/docs)
- [AWS CloudFormation ドキュメント](https://docs.aws.amazon.com/cloudformation/) 