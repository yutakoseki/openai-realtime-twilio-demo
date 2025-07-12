#!/bin/bash

set -e

# 設定
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="ap-northeast-1"
ENVIRONMENT="production"

echo "🏗️ OpenAI Twilio Demo インフラデプロイ開始"
echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"

# 1. VPCの出力値を取得
echo "📊 VPCの出力値を取得中..."
VPC_ID=$(aws cloudformation describe-stacks --stack-name openai-twilio-vpc --query 'Stacks[0].Outputs[?OutputKey==`VPCId`].OutputValue' --output text)
PUBLIC_SUBNET_1=$(aws cloudformation describe-stacks --stack-name openai-twilio-vpc --query 'Stacks[0].Outputs[?OutputKey==`PublicSubnet1`].OutputValue' --output text)
PUBLIC_SUBNET_2=$(aws cloudformation describe-stacks --stack-name openai-twilio-vpc --query 'Stacks[0].Outputs[?OutputKey==`PublicSubnet2`].OutputValue' --output text)
PRIVATE_SUBNET_1=$(aws cloudformation describe-stacks --stack-name openai-twilio-vpc --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnet1`].OutputValue' --output text)
PRIVATE_SUBNET_2=$(aws cloudformation describe-stacks --stack-name openai-twilio-vpc --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnet2`].OutputValue' --output text)
SECURITY_GROUP_ID=$(aws cloudformation describe-stacks --stack-name openai-twilio-vpc --query 'Stacks[0].Outputs[?OutputKey==`SecurityGroupId`].OutputValue' --output text)

echo "VPC ID: $VPC_ID"
echo "Public Subnet 1: $PUBLIC_SUBNET_1"
echo "Public Subnet 2: $PUBLIC_SUBNET_2"
echo "Private Subnet 1: $PRIVATE_SUBNET_1"
echo "Private Subnet 2: $PRIVATE_SUBNET_2"
echo "Security Group ID: $SECURITY_GROUP_ID"

# 2. ドメイン名とSSL証明書の確認
DOMAIN_NAME=$(aws ssm get-parameter --name "/openai-twilio-demo/DOMAIN_NAME" --query 'Parameter.Value' --output text 2>/dev/null || echo "")

if [ -n "$DOMAIN_NAME" ]; then
    echo "🔒 カスタムドメインが設定されています: $DOMAIN_NAME"
    
    # SSL証明書のARNを取得
    CERTIFICATE_ARN=$(aws acm list-certificates --query "CertificateSummaryList[?DomainName=='$DOMAIN_NAME'].CertificateArn" --output text)
    
    if [ -z "$CERTIFICATE_ARN" ]; then
        echo "⚠️ SSL証明書が見つかりません。証明書をリクエストしてください："
        echo "aws acm request-certificate --domain-name $DOMAIN_NAME --subject-alternative-names *.$DOMAIN_NAME --validation-method DNS"
        exit 1
    fi
    
    echo "SSL証明書 ARN: $CERTIFICATE_ARN"
else
    echo "ℹ️ カスタムドメインが設定されていません。ALBのデフォルトDNS名を使用します。"
    CERTIFICATE_ARN=""
fi

# 3. ALBスタックのデプロイ
echo "🌐 ALBスタックをデプロイ中..."
if [ -n "$CERTIFICATE_ARN" ]; then
    aws cloudformation create-stack \
        --stack-name openai-twilio-alb \
        --template-body file://aws/alb.yaml \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=VPCId,ParameterValue=$VPC_ID \
            ParameterKey=PublicSubnet1,ParameterValue=$PUBLIC_SUBNET_1 \
            ParameterKey=PublicSubnet2,ParameterValue=$PUBLIC_SUBNET_2 \
            ParameterKey=SecurityGroupId,ParameterValue=$SECURITY_GROUP_ID \
            ParameterKey=DomainName,ParameterValue=$DOMAIN_NAME \
            ParameterKey=CertificateArn,ParameterValue=$CERTIFICATE_ARN \
        --capabilities CAPABILITY_IAM 2>/dev/null || echo "ALBスタックは既に存在します"
else
    aws cloudformation create-stack \
        --stack-name openai-twilio-alb \
        --template-body file://aws/alb.yaml \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=VPCId,ParameterValue=$VPC_ID \
            ParameterKey=PublicSubnet1,ParameterValue=$PUBLIC_SUBNET_1 \
            ParameterKey=PublicSubnet2,ParameterValue=$PUBLIC_SUBNET_2 \
            ParameterKey=SecurityGroupId,ParameterValue=$SECURITY_GROUP_ID \
            ParameterKey=DomainName,ParameterValue=example.com \
            ParameterKey=CertificateArn,ParameterValue=arn:aws:acm:ap-northeast-1:123456789012:certificate/00000000-0000-0000-0000-000000000000 \
        --capabilities CAPABILITY_IAM 2>/dev/null || echo "ALBスタックは既に存在します"
fi

aws cloudformation wait stack-create-complete --stack-name openai-twilio-alb

# 4. ALBの出力値を取得
echo "📊 ALBの出力値を取得中..."
ALB_DNS=$(aws cloudformation describe-stacks --stack-name openai-twilio-alb --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' --output text)
WEBAPP_TG_ARN=$(aws cloudformation describe-stacks --stack-name openai-twilio-alb --query 'Stacks[0].Outputs[?OutputKey==`TargetGroupWebAppArn`].OutputValue' --output text)
WEBSOCKET_TG_ARN=$(aws cloudformation describe-stacks --stack-name openai-twilio-alb --query 'Stacks[0].Outputs[?OutputKey==`TargetGroupWebSocketArn`].OutputValue' --output text)

echo "ALB DNS: $ALB_DNS"
echo "WebApp Target Group ARN: $WEBAPP_TG_ARN"
echo "WebSocket Target Group ARN: $WEBSOCKET_TG_ARN"

# 5. PUBLIC_URLを更新
echo "🔧 PUBLIC_URLを更新中..."
aws ssm put-parameter \
    --name "/openai-twilio-demo/PUBLIC_URL" \
    --value "https://$ALB_DNS" \
    --type "String" \
    --overwrite

# 6. タスク定義ファイルのACCOUNT_IDを置換
echo "📝 タスク定義ファイルを更新中..."
sed -i "s/ACCOUNT_ID/$ACCOUNT_ID/g" aws/task-definition-websocket.json
sed -i "s/ACCOUNT_ID/$ACCOUNT_ID/g" aws/task-definition-webapp.json

# 7. タスク定義を登録
echo "📋 タスク定義を登録中..."
aws ecs register-task-definition --cli-input-json file://aws/task-definition-websocket.json
aws ecs register-task-definition --cli-input-json file://aws/task-definition-webapp.json

# 8. サービス定義ファイルの値を置換
echo "📝 サービス定義ファイルを更新中..."
sed -i "s|TARGET_GROUP_ARN|$WEBAPP_TG_ARN|g" aws/service-definition-webapp.json
sed -i "s|TARGET_GROUP_ARN|$WEBSOCKET_TG_ARN|g" aws/service-definition-websocket.json
sed -i "s|PRIVATE_SUBNET_1|$PRIVATE_SUBNET_1|g" aws/service-definition-webapp.json
sed -i "s|PRIVATE_SUBNET_2|$PRIVATE_SUBNET_2|g" aws/service-definition-webapp.json
sed -i "s|PRIVATE_SUBNET_1|$PRIVATE_SUBNET_1|g" aws/service-definition-websocket.json
sed -i "s|PRIVATE_SUBNET_2|$PRIVATE_SUBNET_2|g" aws/service-definition-websocket.json
sed -i "s|SECURITY_GROUP_ID|$SECURITY_GROUP_ID|g" aws/service-definition-webapp.json
sed -i "s|SECURITY_GROUP_ID|$SECURITY_GROUP_ID|g" aws/service-definition-websocket.json

# 9. ECSサービスを作成
echo "🚀 ECSサービスを作成中..."
aws ecs create-service --cli-input-json file://aws/service-definition-webapp.json 2>/dev/null || echo "WebAppサービスは既に存在します"
aws ecs create-service --cli-input-json file://aws/service-definition-websocket.json 2>/dev/null || echo "WebSocketサービスは既に存在します"

# 10. CloudWatchアラームのデプロイ
echo "📊 CloudWatchアラームをデプロイ中..."
aws cloudformation create-stack \
    --stack-name openai-twilio-alarms \
    --template-body file://aws/cloudwatch-alarms.yaml \
    --parameters \
        ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
        ParameterKey=SNSNotificationEmail,ParameterValue=admin@example.com \
    --capabilities CAPABILITY_IAM 2>/dev/null || echo "アラームスタックは既に存在します"

aws cloudformation wait stack-create-complete --stack-name openai-twilio-alarms

echo "✅ インフラデプロイ完了！"
echo ""
echo "🌐 アプリケーションURL: https://$ALB_DNS"
echo "📞 Twilio Webhook URL: https://$ALB_DNS/twiml"
echo ""
echo "次のステップ："
echo "1. TwilioコンソールでWebhook URLを設定してください"
echo "2. ./deploy.sh を実行してアプリケーションをデプロイしてください"
echo "3. アプリケーションの動作をテストしてください" 