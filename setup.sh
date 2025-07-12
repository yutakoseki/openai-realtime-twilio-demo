#!/bin/bash

set -e

# 設定
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="ap-northeast-1"
ENVIRONMENT="production"

echo "🚀 OpenAI Twilio Demo 初期セットアップ開始"
echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"

# 1. ECSクラスターの作成
echo "📦 ECSクラスターを作成中..."
aws ecs create-cluster \
    --cluster-name openai-twilio-demo \
    --capacity-providers FARGATE \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1

# 2. タスク実行ロールの作成
echo "🔐 タスク実行ロールを作成中..."
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "ecs-tasks.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }' 2>/dev/null || echo "ロールは既に存在します"

aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws iam put-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-name ParameterStoreAccess \
    --policy-document '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "ssm:GetParameters",
            "secretsmanager:GetSecretValue",
            "kms:Decrypt"
          ],
          "Resource": "*"
        }
      ]
    }'

# 3. ECRリポジトリの作成
echo "📦 ECRリポジトリを作成中..."
aws ecr create-repository --repository-name websocket-server 2>/dev/null || echo "WebSocketリポジトリは既に存在します"
aws ecr create-repository --repository-name webapp 2>/dev/null || echo "WebAppリポジトリは既に存在します"

# 4. CloudWatchロググループの作成
echo "📊 CloudWatchロググループを作成中..."
aws logs create-log-group --log-group-name /ecs/websocket-server 2>/dev/null || echo "WebSocketロググループは既に存在します"
aws logs create-log-group --log-group-name /ecs/webapp 2>/dev/null || echo "WebAppロググループは既に存在します"

aws logs put-retention-policy --log-group-name /ecs/websocket-server --retention-in-days 30
aws logs put-retention-policy --log-group-name /ecs/webapp --retention-in-days 30

# 5. VPCスタックのデプロイ
echo "🌐 VPCスタックをデプロイ中..."
aws cloudformation create-stack \
    --stack-name openai-twilio-vpc \
    --template-body file://aws/vpc.yaml \
    --parameters ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
    --capabilities CAPABILITY_IAM 2>/dev/null || echo "VPCスタックは既に存在します"

aws cloudformation wait stack-create-complete --stack-name openai-twilio-vpc

# 6. WAFスタックのデプロイ
echo "🛡️ WAFスタックをデプロイ中..."
aws cloudformation create-stack \
    --stack-name openai-twilio-waf \
    --template-body file://aws/waf.yaml \
    --parameters ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
    --capabilities CAPABILITY_IAM 2>/dev/null || echo "WAFスタックは既に存在します"

aws cloudformation wait stack-create-complete --stack-name openai-twilio-waf

# 7. 環境変数の設定（ユーザー入力が必要）
echo "🔧 環境変数を設定してください..."
echo "以下のコマンドを実行して環境変数を設定してください："
echo ""
echo "# OpenAI APIキー"
echo "aws ssm put-parameter --name '/openai-twilio-demo/OPENAI_API_KEY' --value 'your-openai-api-key' --type 'SecureString'"
echo ""
echo "# Twilio認証情報"
echo "aws ssm put-parameter --name '/openai-twilio-demo/TWILIO_ACCOUNT_SID' --value 'your-twilio-account-sid' --type 'SecureString'"
echo "aws ssm put-parameter --name '/openai-twilio-demo/TWILIO_AUTH_TOKEN' --value 'your-twilio-auth-token' --type 'SecureString'"
echo ""
echo "# ドメイン名（カスタムドメインがある場合）"
echo "aws ssm put-parameter --name '/openai-twilio-demo/DOMAIN_NAME' --value 'your-domain.com' --type 'String'"

echo "✅ 初期セットアップ完了！"
echo ""
echo "次のステップ："
echo "1. 上記の環境変数を設定してください"
echo "2. SSL証明書を取得してください（カスタムドメインがある場合）"
echo "3. ./deploy-infrastructure.sh を実行してインフラをデプロイしてください" 