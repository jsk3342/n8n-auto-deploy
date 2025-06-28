#!/bin/bash

# n8n 웹 터미널 자동 설치 (비밀번호 자동 생성)
# AWS EC2 Instance Connect에서 직접 실행
# 사용법: curl -sSL URL | bash
# 또는: N8N_PASSWORD=mypass123 bash <(curl -sSL URL)

set -e

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
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
echo -e "${CYAN}=== n8n 자동 설치 ===${NC}"
echo -e "${YELLOW}비밀번호 자동 생성 방식${NC}"
echo ""

# 외부 IP 확인
echo -e "${CYAN}외부 IP 확인 중...${NC}"
EXTERNAL_IP=$(curl -s http://checkip.amazonaws.com/)
echo -e "${GREEN}외부 IP: $EXTERNAL_IP${NC}"
echo ""

# 비밀번호 처리
if [[ -z "$N8N_PASSWORD" ]]; then
    # 자동으로 안전한 비밀번호 생성
    N8N_PASSWORD="n8n$(date +%m%d)$(shuf -i 100-999 -n 1)"
    echo -e "${YELLOW}자동 생성된 비밀번호: $N8N_PASSWORD${NC}"
else
    echo -e "${GREEN}환경변수로 설정된 비밀번호 사용${NC}"
fi
echo ""

# 설치 시작
echo -e "${BLUE}🚀 설치를 시작합니다...${NC}"
echo ""

# 시스템 업데이트
echo -e "${CYAN}📦 시스템 업데이트...${NC}"
sudo apt update > /dev/null 2>&1
echo -e "${GREEN}✅ 완료${NC}"

# Docker 설치 확인 및 설치
echo -e "${CYAN}🐳 Docker 설치 확인...${NC}"
if ! command -v docker &> /dev/null; then
    echo "  Docker 설치 중..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh > /dev/null 2>&1
    sudo usermod -aG docker ubuntu
    rm get-docker.sh
    echo "  Docker 설치 완료"
else
    echo "  Docker가 이미 설치되어 있습니다"
fi
echo -e "${GREEN}✅ 완료${NC}"

# Docker Compose 설치 확인 및 설치
echo -e "${CYAN}📦 Docker Compose 설치 확인...${NC}"
if ! command -v docker-compose &> /dev/null; then
    echo "  Docker Compose 설치 중..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose 2>/dev/null
    sudo chmod +x /usr/local/bin/docker-compose
    echo "  Docker Compose 설치 완료"
else
    echo "  Docker Compose가 이미 설치되어 있습니다"
fi
echo -e "${GREEN}✅ 완료${NC}"

# n8n 디렉토리 및 설정
echo -e "${CYAN}📁 n8n 설정 파일 생성...${NC}"
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
      # 기본 설정
      - N8N_HOST=$EXTERNAL_IP
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      
      # 인증 설정
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD
      
      # 웹훅 설정
      - WEBHOOK_TUNNEL_URL=http://$EXTERNAL_IP:5678
      
      # 데이터베이스
      - DB_TYPE=sqlite
      
      # 타임존
      - GENERIC_TIMEZONE=Asia/Seoul
      - TZ=Asia/Seoul
      
      # 보안 설정
      - N8N_SECURE_COOKIE=false
      - N8N_LOG_LEVEL=info
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=168
      
    volumes:
      - n8n_data:/home/node/.n8n
    
    # 리소스 제한 (프리티어 최적화)
    mem_limit: 512m
    cpus: 0.8
    
    # 로그 관리
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

# 접속 정보 파일 생성
cat > ~/n8n-info.txt << EOF
n8n 접속 정보
=============

URL: http://$EXTERNAL_IP:5678
사용자명: admin
비밀번호: $N8N_PASSWORD

웹훅 URL 형식:
http://$EXTERNAL_IP:5678/webhook/[워크플로우명]

설치 일시: $(date)
EOF

# 방화벽 설정
echo -e "${CYAN}🔥 방화벽 설정...${NC}"
sudo ufw --force enable > /dev/null 2>&1
sudo ufw allow ssh > /dev/null 2>&1
sudo ufw allow 5678 > /dev/null 2>&1
echo -e "${GREEN}✅ 완료${NC}"

# n8n 시작
echo -e "${CYAN}🚀 n8n 컨테이너 시작...${NC}"
sudo docker-compose up -d
echo -e "${GREEN}✅ 완료${NC}"

# 관리 스크립트 생성
echo -e "${CYAN}🛠️  관리 도구 생성...${NC}"
cat > ~/n8n-manager << 'SCRIPT_EOF'
#!/bin/bash

# n8n 관리 스크립트
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
    echo -n "선택 (1-8): "
}

get_external_ip() {
    curl -s http://checkip.amazonaws.com/ 2>/dev/null || echo "IP 확인 실패"
}

while true; do
    show_menu
    read choice
    echo ""
    
    case $choice in
        1) 
            echo -e "${CYAN}=== n8n 상태 ===${NC}"
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
            echo -e "${CYAN}=== n8n 로그 (Ctrl+C로 종료) ===${NC}"
            cd ~/n8n && docker-compose logs --tail=50 -f
            ;;
        6)
            EXTERNAL_IP=$(get_external_ip)
            echo -e "${CYAN}=== 접속 정보 ===${NC}"
            if [[ -f ~/n8n-info.txt ]]; then
                cat ~/n8n-info.txt
            else
                echo -e "${YELLOW}URL: http://$EXTERNAL_IP:5678${NC}"
                echo -e "${YELLOW}사용자명: admin${NC}"
                echo -e "${YELLOW}비밀번호: ~/n8n-info.txt 파일을 확인하세요${NC}"
            fi
            ;;
        7)
            echo -e "${CYAN}백업 생성 중...${NC}"
            BACKUP_NAME="n8n-backup-$(date +%Y%m%d-%H%M%S).json"
            if docker exec n8n n8n export:all --output=/tmp/$BACKUP_NAME 2>/dev/null; then
                docker cp n8n:/tmp/$BACKUP_NAME ./$BACKUP_NAME 2>/dev/null
                echo -e "${GREEN}✅ 백업 완료: $BACKUP_NAME${NC}"
            else
                echo -e "${YELLOW}⚠️  백업 실패 (n8n이 실행 중인지 확인하세요)${NC}"
            fi
            ;;
        8) 
            echo -e "${GREEN}👋 관리 도구를 종료합니다${NC}"
            break
            ;;
        *) 
            echo -e "${YELLOW}1-8 중에서 선택해주세요${NC}"
            ;;
    esac
    echo ""
done
SCRIPT_EOF

chmod +x ~/n8n-manager
echo "alias n8n-manager='~/n8n-manager'" >> ~/.bashrc
echo -e "${GREEN}✅ 완료${NC}"

# 서비스 시작 대기
echo ""
echo -e "${CYAN}⏳ n8n 서비스 시작 대기 중 (30초)...${NC}"
sleep 30

# 최종 상태 확인
echo -e "${CYAN}최종 상태 확인 중...${NC}"
if docker ps | grep -q n8n; then
    SERVICE_STATUS="✅ 실행 중"
else
    SERVICE_STATUS="⚠️  확인 필요"
fi

# HTTP 응답 확인
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 2>/dev/null || echo "000")

# 최종 결과 출력
echo ""
echo -e "${GREEN}🎉 n8n 설치가 완료되었습니다! 🎉${NC}"
echo ""
echo -e "${YELLOW}=== 📱 접속 정보 ===${NC}"
echo -e "${CYAN}🌐 URL: http://$EXTERNAL_IP:5678${NC}"
echo -e "${CYAN}👤 사용자명: admin${NC}"
echo -e "${CYAN}🔐 비밀번호: $N8N_PASSWORD${NC}"
echo ""
echo -e "${YELLOW}=== 🔗 웹훅 URL 형식 ===${NC}"
echo -e "${CYAN}http://$EXTERNAL_IP:5678/webhook/[워크플로우명]${NC}"
echo ""
echo -e "${YELLOW}=== ⚙️  관리 명령어 ===${NC}"
echo -e "${CYAN}n8n-manager${NC} - 관리 메뉴 실행"
echo -e "${CYAN}cat ~/n8n-info.txt${NC} - 접속 정보 확인"
echo ""
echo -e "${YELLOW}=== 📊 시스템 상태 ===${NC}"
echo -e "${CYAN}Docker 컨테이너: $SERVICE_STATUS${NC}"
echo -e "${CYAN}HTTP 응답: $HTTP_STATUS${NC}"
echo ""

if [[ "$HTTP_STATUS" =~ ^(200|401|403)$ ]]; then
    echo -e "${GREEN}🎊 성공! 브라우저에서 http://$EXTERNAL_IP:5678 로 접속하세요! 🎊${NC}"
else
    echo -e "${YELLOW}⏳ n8n이 아직 시작 중일 수 있습니다. 1-2분 후 다시 접속해보세요.${NC}"
fi

echo ""
echo -e "${BLUE}💡 터미널을 닫아도 n8n은 계속 실행됩니다.${NC}"
echo -e "${BLUE}💡 문제가 있으면 'n8n-manager' 명령어를 사용하세요.${NC}"
echo ""
echo -e "${GREEN}🚀 즐거운 자동화 라이프 되세요! 🚀${NC}"