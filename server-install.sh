#!/bin/bash

# n8n 웹 터미널 초간단 설치
# AWS EC2 Instance Connect에서 직접 실행

set -e

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${BLUE}"
echo "  ███╗   ██╗ █████╗ ███╗   ██╗"
echo "  ████╗  ██║██╔══██╗████╗  ██║"
echo "  ██╔██╗ ██║╚█████╔╝██╔██╗ ██║"
echo "  ██║╚██╗██║██╔══██╗██║╚██╗██║"
echo "  ██║ ╚████║╚█████╔╝██║ ╚████║"
echo "  ╚═╝  ╚═══╝ ╚════╝ ╚═╝  ╚═══╝"
echo -e "${NC}"
echo -e "${CYAN}=== n8n 초간단 설치 ===${NC}"
echo ""

# 외부 IP 확인
echo -e "${CYAN}외부 IP 확인 중...${NC}"
EXTERNAL_IP=$(curl -s http://checkip.amazonaws.com/)
echo -e "${GREEN}외부 IP: $EXTERNAL_IP${NC}"
echo ""

# 비밀번호 입력 (일반 텍스트로)
echo -e "${YELLOW}n8n 관리자 비밀번호를 입력하세요 (8자 이상):${NC}"
read -p "비밀번호: " N8N_PASSWORD

# 비밀번호 길이 확인
if [[ ${#N8N_PASSWORD} -lt 8 ]]; then
    echo "비밀번호는 8자 이상이어야 합니다. 다시 실행해주세요."
    exit 1
fi

echo ""
echo -e "${GREEN}✅ 비밀번호 설정 완료: $N8N_PASSWORD${NC}"
echo ""

# 설치 시작
echo -e "${BLUE}🚀 설치를 시작합니다...${NC}"
echo ""

# 시스템 업데이트
echo -e "${CYAN}📦 시스템 업데이트...${NC}"
sudo apt update > /dev/null 2>&1
echo -e "${GREEN}✅ 완료${NC}"

# Docker 설치
echo -e "${CYAN}🐳 Docker 설치...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh > /dev/null 2>&1
    sudo usermod -aG docker ubuntu
    rm get-docker.sh
fi
echo -e "${GREEN}✅ 완료${NC}"

# Docker Compose 설치
echo -e "${CYAN}📦 Docker Compose 설치...${NC}"
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose 2>/dev/null
    sudo chmod +x /usr/local/bin/docker-compose
fi
echo -e "${GREEN}✅ 완료${NC}"

# n8n 설정
echo -e "${CYAN}📁 n8n 설정...${NC}"
mkdir -p ~/n8n
cd ~/n8n

# Docker Compose 파일 생성
cat > docker-compose.yml << EOF
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=$EXTERNAL_IP
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD
      - WEBHOOK_TUNNEL_URL=http://$EXTERNAL_IP:5678
      - DB_TYPE=sqlite
      - GENERIC_TIMEZONE=Asia/Seoul
      - TZ=Asia/Seoul
      - N8N_SECURE_COOKIE=false
      - N8N_LOG_LEVEL=info
    volumes:
      - n8n_data:/home/node/.n8n
    mem_limit: 512m
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  n8n_data:
    driver: local
EOF

echo -e "${GREEN}✅ 완료${NC}"

# 방화벽 설정
echo -e "${CYAN}🔥 방화벽 설정...${NC}"
sudo ufw --force enable > /dev/null 2>&1
sudo ufw allow ssh > /dev/null 2>&1
sudo ufw allow 5678 > /dev/null 2>&1
echo -e "${GREEN}✅ 완료${NC}"

# n8n 시작
echo -e "${CYAN}🚀 n8n 시작...${NC}"
sudo docker-compose up -d
echo -e "${GREEN}✅ 완료${NC}"

# 관리 스크립트 생성
echo -e "${CYAN}🛠️  관리 도구 생성...${NC}"
cat > ~/n8n-control.sh << 'SCRIPT_EOF'
#!/bin/bash
echo "=== n8n 관리 도구 ==="
echo "1) 상태 확인"
echo "2) 재시작"
echo "3) 로그 보기"
echo "4) 접속 정보"
read -p "선택: " choice

case $choice in
    1) cd ~/n8n && docker ps ;;
    2) cd ~/n8n && docker-compose restart && echo "재시작 완료" ;;
    3) cd ~/n8n && docker-compose logs --tail=50 ;;
    4) 
        IP=$(curl -s http://checkip.amazonaws.com/)
        echo "URL: http://$IP:5678"
        echo "사용자명: admin"
        echo "비밀번호: [설정한 비밀번호]"
        ;;
esac
SCRIPT_EOF

chmod +x ~/n8n-control.sh
echo "alias n8n-control='~/n8n-control.sh'" >> ~/.bashrc
echo -e "${GREEN}✅ 완료${NC}"

# 서비스 시작 대기
echo ""
echo -e "${CYAN}⏳ n8n 시작 대기 중...${NC}"
sleep 30

# 최종 결과
echo ""
echo -e "${GREEN}🎉 n8n 설치 완료! 🎉${NC}"
echo ""
echo -e "${YELLOW}=== 접속 정보 ===${NC}"
echo -e "${CYAN}URL: http://$EXTERNAL_IP:5678${NC}"
echo -e "${CYAN}사용자명: admin${NC}"
echo -e "${CYAN}비밀번호: $N8N_PASSWORD${NC}"
echo ""
echo -e "${YELLOW}=== 관리 명령어 ===${NC}"
echo -e "${CYAN}n8n-control${NC} - 관리 메뉴"
echo -e "${CYAN}cd ~/n8n && docker ps${NC} - 상태 확인"
echo ""

# 상태 확인
echo -e "${CYAN}최종 상태 확인:${NC}"
if docker ps | grep -q n8n; then
    echo -e "${GREEN}✅ n8n이 실행 중입니다!${NC}"
    echo -e "${GREEN}브라우저에서 http://$EXTERNAL_IP:5678 로 접속하세요!${NC}"
else
    echo -e "${YELLOW}⚠️  잠시 후 다시 확인해주세요.${NC}"
fi

echo ""
echo -e "${BLUE}🚀 설치 완료! 🚀${NC}"