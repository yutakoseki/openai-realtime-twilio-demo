# Dockerのインストール
sudo apt update
sudo apt install -y docker.io

# Dockerサービスを開始
sudo systemctl start docker
sudo systemctl enable docker

# 現在のユーザーをdockerグループに追加
sudo usermod -aG docker $USER

# 新しいグループ設定を反映（ログアウト・ログインするか、以下を実行）
newgrp docker