/** @type {import('next').NextConfig} */
const nextConfig = {
  // Amplify用の設定
  output: 'export',
  trailingSlash: true,
  images: {
    unoptimized: true
  },
  // 環境変数の設定
  env: {
    NEXT_PUBLIC_WEBSOCKET_URL: process.env.NEXT_PUBLIC_WEBSOCKET_URL || 'wss://production-alb-981597197.ap-northeast-1.elb.amazonaws.com'
  }
};

export default nextConfig;
