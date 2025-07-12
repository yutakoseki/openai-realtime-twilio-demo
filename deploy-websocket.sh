#!/bin/bash

set -e

# 設定
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="ap-northeast-1"
ECR_REPO_WEBSOCKET="websocket-server"
CLUSTER_NAME="openai-twilio-demo"

echo "🚀 OpenAI Twilio Demo WebSocketサーバーデプロイ開始"
echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"

# ECRログイン
echo "📦 ECRにログイン中..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# WebSocketサーバーのビルドとプッシュ
echo "🔨 WebSocketサーバーをビルド中..."
cd websocket-server
docker build -t $ECR_REPO_WEBSOCKET .
docker tag $ECR_REPO_WEBSOCKET:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO_WEBSOCKET:latest
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO_WEBSOCKET:latest
cd ..

# タスク定義の更新
echo "📝 タスク定義を更新中..."
aws ecs register-task-definition --cli-input-json file://aws/task-definition-websocket.json

# サービスの更新
echo "🔄 サービスを更新中..."
aws ecs update-service --cluster $CLUSTER_NAME --service websocket-server --force-new-deployment

echo "✅ WebSocketサーバーデプロイ完了！"
echo "ALB DNS: $(aws cloudformation describe-stacks --stack-name openai-twilio-alb --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' --output text)" 