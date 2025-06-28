#!/bin/bash

# n8n 웹 터미널 설치 스크립트
# AWS EC2 Instance Connect에서 직접 실행
# 사용법: curl -sSL https://raw.githubusercontent.com/jsk3342/n8n-auto-deploy/main/server-install.sh | bash

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 로고 출력
echo -e "${BLUE}"
echo "  ███╗   ██╗ █████╗ ███╗   ██╗"
echo "  ████╗  ██║██╔══██╗████╗  ██║"
echo "  ██╔██╗ ██║╚█████╔╝██╔██╗ ██║"
echo "  ██║╚██╗██║██╔══██╗██║╚██╗██║"
echo "  ██║ ╚████║╚█████╔╝██║ ╚████║"
echo "  ╚═╝  ╚═══╝ ╚════╝ ╚═╝  ╚═══╝"
echo -e "${NC}"
echo -e "${CYAN}=== n8n 웹 터미널 설치 ===${NC}"
echo -e "${YELLOW}간단하고 안전한 원클릭 설치${NC}"
echo ""

# 외부 IP 확인
echo -e "${CYAN}외부 IP 확인 중...${NC}"
EXTERNAL_IP=$(curl -s http://checkip.amazonaws.com/ 2>/dev/null)
if [[ -z "$EXTERNAL_IP" ]]; then
    echo -e "${RED}외부 IP를 자동으로 확인할 수 없습니다.${NC}"
    read -p "탄력적 IP 주소를 입력하세요: " EXTERNAL_IP
fi
echo -e "${GREEN}외부 IP: $EXTERNAL_IP${NC}"
echo ""

# 비밀번호 입력
echo -e "${CYAN}n8n 관리자 비밀번호를 설정하세요:${NC}"
while true; do
    read -s -p "비밀번호 (8자 이상): " N8N_PASSWORD
    echo ""
    if [[ ${#N8N_PASSWORD} -ge 8 ]]; then
        read -s -p "비밀번호 확인: " N8N_PASSWORD_CONFIRM
        echo ""
        if [[ "$N8N_PASSWORD" == "$N8N_PASSWORD_CONFIRM" ]]; then
            echo -e "${GREEN}✅ 비밀번호 설정 완료${NC}"
            break
        else
            echo -e "${RED}❌ 비밀번호가 일치하지 않습니다.${NC}"
        fi
    else
        echo -e "${RED}❌ 비밀번호는 8자 이상이어야 합니다.${NC}"
    fi
done
echo ""

# 설치 시작
echo -e "${BLUE}🚀 n8n 설치를 시작합니다...${NC}"
echo ""

# 시스템 업데이트
echo -e "${CYAN}📦 시스템 업데이트 중...${NC}"
sudo apt update > /dev/null 2>&1
echo -e "${GREEN}✅ 시스템 업데이트 완료${NC}"

# Docker 설치
echo -e "${CYAN}🐳 Docker 설치 중...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh > /dev/null 2>&1
    sudo usermod -aG docker ubuntu
    rm get-docker.sh
    echo -e "${GREEN}✅ Docker 설치 완료${NC}"
else
    echo -e "${GREEN}✅ Docker가 이미 설치되어 있습니다${NC}"
fi

# Docker Compose 설치
echo -e "${CYAN}📦 Docker Compose 설치 중...${NC}"
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose 2>/dev/null
    sudo chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✅ Docker Compose 설치 완료${NC}"
else
    echo -e "${GREEN}✅ Docker Compose가 이미 설치되어 있습니다${NC}"
fi

# n8n 디렉토리 및 설정
echo -e "${CYAN}📁 n8n 설정 중...${NC}"
mkdir -p ~/n8n
cd ~/n8n

# 환경 변수 파일 생성
cat > .env << EOF
N8N_HOST=$EXTERNAL_IP
N8N_PORT=5678
N8N_PROTOCOL=http
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD
WEBHOOK_TUNNEL_URL=http://$EXTERNAL_IP:5678
DB_TYPE=sqlite
GENERIC_TIMEZONE=Asia/Seoul
TZ=Asia/Seoul
N8N_SECURE_COOKIE=false
N8N_LOG_LEVEL=info
EOF

# Docker Compose 파일 생성
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    env_file:
      - .env
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
EOF

echo -e "${GREEN}✅ n8n 설정 완료${NC}"

# 방화벽 설정
echo -e "${CYAN}🔥 방화벽 설정 중...${NC}"
sudo ufw --force enable > /dev/null 2>&1
sudo ufw allow ssh > /dev/null 2>&1
sudo ufw allow 5678 > /dev/null 2>&1
echo -e "${GREEN}✅ 방화벽 설정 완료${NC}"

# n8n 시작
echo -e "${CYAN}🚀 n8n 시작 중...${NC}"
newgrp docker << 'ENDGROUP'
cd ~/n8n
docker-compose up -d
ENDGROUP

# 서비스 시작 대기
echo -e "${CYAN}⏳ n8n 서비스 시작 대기 중 (30초)...${NC}"
sleep 30

# 상태 확인
if docker ps | grep -q n8n > /dev/null 2>&1; then
    echo -e "${GREEN}✅ n8n이 성공적으로 시작되었습니다!${NC}"
else
    echo -e "${YELLOW}⚠️  n8n 상태를 확인 중입니다...${NC}"
fi

# 관리 스크립트 생성
echo -e "${CYAN}🛠️  관리 도구 생성 중...${NC}"
cat > ~/n8n-manager.sh << 'SCRIPT_EOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_menu() {
    echo -e "${BLUE}=== n8n 관리 도구 ===${NC}"
    echo "1) 상태 확인"
    echo "2) 시작"
    echo "3) 중지"
    echo "4) 재시작"
    echo "5) 로그 보기"
    echo "6) 접속 정보"
    echo "7) 백업"
    echo "8) 종료"
    read -p "선택: " choice
}

get_external_ip() {
    curl -s http://checkip.amazonaws.com/ 2>/dev/null
}

while true; do
    show_menu
    case $choice in
        1) 
            cd ~/n8n && docker-compose ps
            ;;
        2) 
            cd ~/n8n && docker-compose up -d
            echo -e "${GREEN}✅ n8n 시작됨${NC}"
            ;;
        3) 
            cd ~/n8n && docker-compose down
            echo -e "${YELLOW}⏹️ n8n 중지됨${NC}"
            ;;
        4) 
            cd ~/n8n && docker-compose restart
            echo -e "${GREEN}🔄 n8n 재시작됨${NC}"
            ;;
        5) 
            cd ~/n8n && docker-compose logs --tail=50 -f
            ;;
        6)
            EXTERNAL_IP=$(get_external_ip)
            echo -e "${CYAN}=== 접속 정보 ===${NC}"
            echo -e "${YELLOW}URL:${NC} http://$EXTERNAL_IP:5678"
            echo -e "${YELLOW}사용자명:${NC} admin"
            echo -e "${YELLOW}비밀번호:${NC} [설정한 비밀번호]"
            ;;
        7)
            BACKUP_NAME="n8n-backup-$(date +%Y%m%d-%H%M%S).json"
            docker exec n8n n8n export:all --output=/tmp/$BACKUP_NAME 2>/dev/null
            docker cp n8n:/tmp/$BACKUP_NAME ./$BACKUP_NAME 2>/dev/null
            echo -e "${GREEN}✅ 백업 완료: $BACKUP_NAME${NC}"
            ;;
        8) 
            echo -e "${GREEN}👋 종료합니다${NC}"
            break
            ;;
        *) 
            echo -e "${RED}❌ 잘못된 선택입니다${NC}"
            ;;
    esac
    echo ""
done
SCRIPT_EOF

chmod +x ~/n8n-manager.sh

# 별칭 추가
echo "alias n8n-manager='~/n8n-manager.sh'" >> ~/.bashrc
echo "alias n8n-status='cd ~/n8n && docker ps'" >> ~/.bashrc
echo "alias n8n-logs='cd ~/n8n && docker-compose logs -f'" >> ~/.bashrc

echo -e "${GREEN}✅ 관리 도구 생성 완료${NC}"
echo ""

# 최종 결과
echo -e "${GREEN}🎉 n8n 설치가 완료되었습니다! 🎉${NC}"
echo ""
echo -e "${CYAN}=== 접속 정보 ===${NC}"
echo -e "${YELLOW}n8n URL:${NC} http://$EXTERNAL_IP:5678"
echo -e "${YELLOW}사용자명:${NC} admin"
echo -e "${YELLOW}비밀번호:${NC} [방금 설정한 비밀번호]"
echo ""
echo -e "${CYAN}=== 관리 명령어 ===${NC}"
echo -e "${BLUE}n8n-manager${NC}   # 관리 메뉴"
echo -e "${BLUE}n8n-status${NC}    # 상태 확인"
echo -e "${BLUE}n8n-logs${NC}      # 로그 보기"
echo ""
echo -e "${GREEN}✅ 브라우저에서 위 URL로 접속하세요!${NC}"
echo -e "${YELLOW}💡 웹 터미널을 닫아도 n8n은 계속 실행됩니다.${NC}"
echo ""

# 최종 상태 확인
echo -e "${CYAN}최종 상태 확인:${NC}"
sleep 5
if curl -s http://localhost:5678 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ n8n 서비스가 정상적으로 실행 중입니다!${NC}"
else
    echo -e "${YELLOW}⚠️  n8n이 아직 시작 중일 수 있습니다. 잠시 후 다시 확인해주세요.${NC}"
fi

echo ""
echo -e "${BLUE}🚀 설치 완료! 즐거운 자동화 라이프 되세요! 🚀${NC}"