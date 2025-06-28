#!/bin/bash

# n8n 간단 설치 스크립트 (최종 버전)
# 사용법: curl -sSL https://raw.githubusercontent.com/jsk3342/n8n-auto-deploy/main/server-install.sh | N8N_PASSWORD=mypass123 bash

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
echo -e "${CYAN}=== n8n 자동화 플랫폼 설치 ===${NC}"
echo -e "${YELLOW}AWS EC2에서 5분만에 완성하는 자동화 환경${NC}"
echo ""

# 외부 IP 확인
echo -e "${CYAN}외부 IP 확인 중...${NC}"
EXTERNAL_IP=$(curl -s http://checkip.amazonaws.com/)
echo -e "${GREEN}외부 IP: $EXTERNAL_IP${NC}"
echo ""

# 비밀번호 처리
if [[ -z "$N8N_PASSWORD" ]]; then
    N8N_PASSWORD="n8n$(date +%m%d)$(shuf -i 100-999 -n 1)"
    echo -e "${YELLOW}자동 생성된 비밀번호: $N8N_PASSWORD${NC}"
else
    echo -e "${GREEN}사용자 지정 비밀번호 설정됨${NC}"
fi
echo ""

# 설치 시작
echo -e "${BLUE}🚀 n8n 설치를 시작합니다...${NC}"
echo ""

# 시스템 업데이트
echo -e "${CYAN}📦 시스템 업데이트...${NC}"
sudo apt update > /dev/null 2>&1
echo -e "${GREEN}✅ 완료${NC}"

# Docker 설치
echo -e "${CYAN}🐳 Docker 설치 확인...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh > /dev/null 2>&1
    rm get-docker.sh
fi
echo -e "${GREEN}✅ 완료${NC}"

# Docker Compose 설치
echo -e "${CYAN}📦 Docker Compose 설치 확인...${NC}"
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

# 관리 도구 생성
echo -e "${CYAN}🛠️  관리 도구 생성...${NC}"
cat > ~/n8n-manager << 'MANAGER_EOF'
#!/bin/bash

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

while true; do
    show_menu
    read choice
    echo ""
    
    case $choice in
        1) 
            echo -e "${CYAN}=== n8n 상태 ===${NC}"
            cd ~/n8n && sudo docker-compose ps
            ;;
        2) 
            cd ~/n8n && sudo docker-compose up -d
            echo -e "${GREEN}✅ n8n 시작됨${NC}"
            ;;
        3) 
            cd ~/n8n && sudo docker-compose down
            echo -e "${YELLOW}⏹️ n8n 중지됨${NC}"
            ;;
        4) 
            cd ~/n8n && sudo docker-compose restart
            echo -e "${GREEN}🔄 n8n 재시작됨${NC}"
            ;;
        5) 
            echo -e "${CYAN}=== n8n 로그 (Ctrl+C로 종료) ===${NC}"
            cd ~/n8n && sudo docker-compose logs --tail=50 -f
            ;;
        6)
            EXTERNAL_IP=$(curl -s http://checkip.amazonaws.com/ 2>/dev/null)
            echo -e "${CYAN}=== 접속 정보 ===${NC}"
            echo -e "${YELLOW}URL: http://$EXTERNAL_IP:5678${NC}"
            echo -e "${YELLOW}사용자명: admin${NC}"
            if [[ -f ~/n8n-info.txt ]]; then
                echo -e "${YELLOW}비밀번호: $(grep 'Password:' ~/n8n-info.txt | cut -d' ' -f2)${NC}"
            else
                echo -e "${YELLOW}비밀번호: 설치시 설정한 비밀번호${NC}"
            fi
            ;;
        7)
            echo -e "${CYAN}백업 생성 중...${NC}"
            BACKUP_NAME="n8n-backup-$(date +%Y%m%d-%H%M%S).json"
            if sudo docker exec n8n n8n export:all --output=/tmp/$BACKUP_NAME 2>/dev/null; then
                sudo docker cp n8n:/tmp/$BACKUP_NAME ./$BACKUP_NAME 2>/dev/null
                echo -e "${GREEN}✅ 백업 완료: $BACKUP_NAME${NC}"
            else
                echo -e "${YELLOW}⚠️  백업 실패${NC}"
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
MANAGER_EOF

chmod +x ~/n8n-manager
echo "alias n8n-manager='~/n8n-manager'" >> ~/.bashrc
echo -e "${GREEN}✅ 완료${NC}"

# 접속 정보 파일 생성
cat > ~/n8n-info.txt << EOF
n8n 자동화 플랫폼 설치 완료
===========================

접속 정보:
URL: http://$EXTERNAL_IP:5678
Username: admin
Password: $N8N_PASSWORD

관리 명령어:
- n8n-manager: 관리 메뉴

설치 일시: $(date)
EOF

# 서비스 시작 대기
echo ""
echo -e "${CYAN}⏳ n8n 서비스 시작 대기 중 (30초)...${NC}"
sleep 30

# 최종 상태 확인
echo -e "${CYAN}최종 상태 확인 중...${NC}"
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
echo -e "${YELLOW}=== 🔗 워크플로우 템플릿 ===${NC}"
echo -e "${CYAN}n8n에서 'Import workflow' → 'From URL'로 다음 링크들을 사용하세요:${NC}"
echo ""
echo -e "${BLUE}1. AI 비서 극존칭 출근 알림${NC}"
echo "   https://raw.githubusercontent.com/jsk3342/n8n-auto-deploy/main/workflows/basic/ai-secretary-commute.json"
echo ""
echo -e "${BLUE}2. 간단한 웹훅 테스트${NC}"
echo "   https://raw.githubusercontent.com/jsk3342/n8n-auto-deploy/main/workflows/basic/simple-webhook-test.json"
echo ""

echo ""
echo -e "${YELLOW}=== 🚀 다음 단계 ===${NC}"
echo -e "${CYAN}1. 브라우저에서 http://$EXTERNAL_IP:5678 접속${NC}"
echo -e "${CYAN}2. admin / $N8N_PASSWORD 로 로그인${NC}"
echo -e "${CYAN}3. 위 URL들로 워크플로우 임포트${NC}"
echo -e "${CYAN}4. 각 워크플로우를 'Active' 상태로 변경${NC}"
echo ""
echo -e "${YELLOW}=== ⚙️  관리 명령어 ===${NC}"
echo -e "${CYAN}n8n-manager${NC} - 관리 메뉴"
echo ""

if [[ "$HTTP_STATUS" =~ ^(200|401|403)$ ]]; then
    echo -e "${GREEN}🎊 성공! 이제 브라우저에서 접속하여 자동화를 시작하세요! 🎊${NC}"
else
    echo -e "${YELLOW}⏳ n8n이 아직 시작 중일 수 있습니다. 1-2분 후 다시 접속해보세요.${NC}"
fi

echo ""
echo -e "${BLUE}💡 터미널을 닫아도 n8n은 계속 실행됩니다.${NC}"
echo -e "${BLUE}🚀 즐거운 자동화 라이프 되세요! 🚀${NC}"