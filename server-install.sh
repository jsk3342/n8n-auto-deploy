#!/bin/bash

# n8n 서버 직접 설치 스크립트 (웹 터미널용)
# AWS EC2 Instance Connect 웹 터미널에서 직접 실행
# 사용법: curl -sSL https://raw.githubusercontent.com/jsk3342/n8n-auto-deploy/main/server-install.sh | bash

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 로고 및 인트로
show_intro() {
    clear
    echo -e "${BLUE}"
    echo "  ███╗   ██╗ █████╗ ███╗   ██╗"
    echo "  ████╗  ██║██╔══██╗████╗  ██║"
    echo "  ██╔██╗ ██║╚█████╔╝██╔██╗ ██║"
    echo "  ██║╚██╗██║██╔══██╗██║╚██╗██║"
    echo "  ██║ ╚████║╚█████╔╝██║ ╚████║"
    echo "  ╚═╝  ╚═══╝ ╚════╝ ╚═╝  ╚═══╝"
    echo -e "${NC}"
    echo -e "${CYAN}=== n8n 서버 직접 설치 ===${NC}"
    echo -e "${YELLOW}AWS 웹 터미널에서 실행하는 간편 설치${NC}"
    echo ""
    echo -e "${GREEN}✅ Docker + n8n 자동 설치${NC}"
    echo -e "${GREEN}✅ 프리티어 최적화 설정${NC}"
    echo -e "${GREEN}✅ 방화벽 자동 구성${NC}"
    echo -e "${GREEN}✅ 관리 도구 포함${NC}"
    echo ""
}

# 에러 처리
error_exit() {
    echo -e "${RED}❌ 오류: $1${NC}" >&2
    exit 1
}

# 성공 메시지
success_msg() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 정보 메시지
info_msg() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# 경고 메시지
warn_msg() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 현재 서버 정보 확인
check_server_info() {
    info_msg "서버 정보 확인 중..."
    
    # 외부 IP 확인
    EXTERNAL_IP=$(curl -s http://checkip.amazonaws.com/ 2>/dev/null || curl -s https://ipinfo.io/ip 2>/dev/null)
    
    if [[ -z "$EXTERNAL_IP" ]]; then
        warn_msg "외부 IP를 자동으로 확인할 수 없습니다."
        read -p "탄력적 IP 주소를 입력하세요: " EXTERNAL_IP
    fi
    
    echo -e "${CYAN}서버 사양:${NC}"
    echo "  외부 IP: $EXTERNAL_IP"
    echo "  OS: $(lsb_release -d | cut -f2 2>/dev/null || echo 'Unknown')"
    echo "  Architecture: $(uname -m)"
    echo "  Memory: $(free -h | grep Mem | awk '{print $2}')"
    echo "  Disk: $(df -h / | tail -1 | awk '{print $2}')"
    echo "  CPU Cores: $(nproc)"
    echo ""
    
    success_msg "서버 정보 확인 완료"
}

# n8n 관리자 비밀번호 설정
get_password() {
    echo -e "${CYAN}=== n8n 설정 ===${NC}"
    echo ""
    
    while true; do
        read -s -p "n8n 관리자 비밀번호 (8자 이상): " N8N_PASSWORD
        echo ""
        if [[ ${#N8N_PASSWORD} -ge 8 ]]; then
            read -s -p "비밀번호 확인: " N8N_PASSWORD_CONFIRM
            echo ""
            if [[ "$N8N_PASSWORD" == "$N8N_PASSWORD_CONFIRM" ]]; then
                break
            else
                warn_msg "비밀번호가 일치하지 않습니다."
            fi
        else
            warn_msg "비밀번호는 8자 이상이어야 합니다."
        fi
    done
    
    success_msg "비밀번호 설정 완료"
    echo ""
}

# n8n 설치
install_n8n() {
    info_msg "n8n 설치 시작... (약 3-5분 소요)"
    echo ""
    
    echo "🔄 시스템 업데이트 중..."
    sudo apt update -qq && sudo apt upgrade -y -qq
    success_msg "시스템 업데이트 완료"
    
    echo "🐳 Docker 설치 중..."
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh > /dev/null 2>&1
        sudo usermod -aG docker ubuntu
        rm get-docker.sh
        success_msg "Docker 설치 완료"
    else
        success_msg "Docker가 이미 설치되어 있습니다"
    fi
    
    echo "📦 Docker Compose 설치 중..."
    if ! command -v docker-compose &> /dev/null; then
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        success_msg "Docker Compose 설치 완료"
    else
        success_msg "Docker Compose가 이미 설치되어 있습니다"
    fi
    
    echo "📁 n8n 디렉토리 설정 중..."
    mkdir -p ~/n8n
    cd ~/n8n
    
    echo "⚙️  n8n 환경 설정 중..."
    cat > .env << EOL
# n8n 기본 설정
N8N_HOST=$EXTERNAL_IP
N8N_PORT=5678
N8N_PROTOCOL=http

# 인증 설정
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD

# 웹훅 URL 설정
WEBHOOK_TUNNEL_URL=http://$EXTERNAL_IP:5678

# 데이터베이스 (SQLite)
DB_TYPE=sqlite

# 타임존 설정
GENERIC_TIMEZONE=Asia/Seoul
TZ=Asia/Seoul

# 보안 및 성능 설정
N8N_SECURE_COOKIE=false
N8N_LOG_LEVEL=info
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=168
N8N_METRICS=false

# 프리티어 최적화
N8N_CONCURRENCY_PRODUCTION=1
EOL

    echo "🐳 Docker Compose 설정 중..."
    cat > docker-compose.yml << 'EOL'
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
    
    # 프리티어 최적화 설정
    mem_limit: 512m
    cpus: '0.8'
    
    # 로그 관리 (디스크 공간 절약)
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    
    # 헬스체크
    healthcheck:
      test: ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost:5678/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

volumes:
  n8n_data:
    driver: local
EOL

    success_msg "설정 파일 생성 완료"
    
    echo "🔥 방화벽 설정 중..."
    sudo ufw --force enable > /dev/null 2>&1
    sudo ufw allow ssh > /dev/null 2>&1
    sudo ufw allow 5678 > /dev/null 2>&1
    success_msg "방화벽 설정 완료"
    
    echo "🚀 n8n 시작 중..."
    # Docker 그룹 적용을 위해 새 세션에서 실행
    sudo -u ubuntu bash << 'DOCKER_EOF'
        cd ~/n8n
        docker-compose up -d
DOCKER_EOF
    
    # 서비스 시작 대기
    echo "⏳ n8n 서비스 시작 대기 중..."
    sleep 30
    
    # 상태 확인
    if docker ps | grep -q n8n; then
        success_msg "n8n 컨테이너가 실행 중입니다"
    else
        warn_msg "n8n 컨테이너 상태를 확인해주세요"
    fi
    
    success_msg "n8n 설치 완료"
}

# 설치 확인
verify_installation() {
    info_msg "n8n 서비스 확인 중..."
    
    # 잠시 대기 (서비스 완전 시작 대기)
    sleep 15
    
    # HTTP 상태 확인
    local max_attempts=12
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5678" 2>/dev/null)
        
        if [[ "$HTTP_STATUS" =~ ^(200|401|403)$ ]]; then
            success_msg "n8n 서비스가 정상적으로 실행 중입니다"
            return 0
        fi
        
        if [[ $attempt -eq 6 ]]; then
            warn_msg "서비스 시작에 시간이 걸리고 있습니다..."
            echo "   Docker가 이미지를 다운로드하고 있을 수 있습니다."
        fi
        
        info_msg "n8n 서비스 확인 시도 $attempt/$max_attempts (HTTP: $HTTP_STATUS)... 10초 후 재시도"
        sleep 10
        ((attempt++))
    done
    
    warn_msg "n8n 서비스 확인에 실패했습니다."
    echo "   수동으로 확인: http://$EXTERNAL_IP:5678"
}

# 관리 스크립트 생성
create_management_scripts() {
    info_msg "관리 도구 설치 중..."
    
    # n8n 관리 스크립트 생성
    cat > ~/n8n-manager.sh << 'SCRIPT_EOF'
#!/bin/bash

# n8n 관리 스크립트

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_menu() {
    echo -e "${BLUE}=== n8n 관리 도구 ===${NC}"
    echo "1) n8n 상태 확인"
    echo "2) n8n 시작"
    echo "3) n8n 중지"
    echo "4) n8n 재시작"
    echo "5) n8n 로그 보기"
    echo "6) 시스템 정보"
    echo "7) 백업 생성"
    echo "8) 시스템 정리"
    echo "9) 접속 정보 표시"
    echo "10) 종료"
    echo -n "선택: "
}

get_external_ip() {
    curl -s http://checkip.amazonaws.com/ 2>/dev/null || curl -s https://ipinfo.io/ip 2>/dev/null || echo "IP 확인 실패"
}

while true; do
    show_menu
    read choice
    
    case $choice in
        1) 
            echo -e "${CYAN}=== n8n 상태 ===${NC}"
            cd ~/n8n && docker-compose ps
            echo ""
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
            echo -e "${CYAN}=== 시스템 정보 ===${NC}"
            echo "메모리: $(free -h | grep Mem | awk '{print $3"/"$2}')"
            echo "디스크: $(df -h / | tail -1 | awk '{print $3"/"$2" ("$5")"}')"
            echo "업타임: $(uptime -p)"
            echo "외부 IP: $(get_external_ip)"
            echo ""
            ;;
        7)
            echo -e "${CYAN}백업 생성 중...${NC}"
            BACKUP_NAME="n8n-backup-$(date +%Y%m%d-%H%M%S).json"
            docker exec n8n n8n export:all --output=/tmp/$BACKUP_NAME 2>/dev/null
            docker cp n8n:/tmp/$BACKUP_NAME ./$BACKUP_NAME 2>/dev/null
            echo -e "${GREEN}✅ 백업 완료: $BACKUP_NAME${NC}"
            ;;
        8)
            echo -e "${CYAN}시스템 정리 중...${NC}"
            docker system prune -f > /dev/null
            sudo apt autoremove -y > /dev/null 2>&1
            echo -e "${GREEN}🧹 정리 완료${NC}"
            ;;
        9)
            EXTERNAL_IP=$(get_external_ip)
            echo -e "${CYAN}=== n8n 접속 정보 ===${NC}"
            echo -e "${YELLOW}URL:${NC} http://$EXTERNAL_IP:5678"
            echo -e "${YELLOW}사용자명:${NC} admin"
            echo -e "${YELLOW}비밀번호:${NC} [설정한 비밀번호]"
            echo -e "${YELLOW}웹훅 URL:${NC} http://$EXTERNAL_IP:5678/webhook/[워크플로우명]"
            echo ""
            ;;
        10) 
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
    
    # 바로가기 별칭 추가
    echo "" >> ~/.bashrc
    echo "# n8n 관리 도구" >> ~/.bashrc
    echo "alias n8n-manager='~/n8n-manager.sh'" >> ~/.bashrc
    echo "alias n8n-logs='cd ~/n8n && docker-compose logs -f'" >> ~/.bashrc
    echo "alias n8n-status='cd ~/n8n && docker-compose ps'" >> ~/.bashrc
    
    success_msg "관리 도구 설치 완료"
}

# 최종 정보 출력
show_completion_info() {
    echo ""
    echo -e "${GREEN}🎉 n8n 설치가 완료되었습니다! 🎉${NC}"
    echo ""
    echo -e "${CYAN}=== 접속 정보 ===${NC}"
    echo -e "${YELLOW}n8n URL:${NC} http://$EXTERNAL_IP:5678"
    echo -e "${YELLOW}사용자명:${NC} admin"
    echo -e "${YELLOW}비밀번호:${NC} [설정한 비밀번호]"
    echo ""
    echo -e "${CYAN}=== 웹훅 URL 형식 ===${NC}"
    echo -e "${YELLOW}기본 웹훅:${NC} http://$EXTERNAL_IP:5678/webhook/워크플로우명"
    echo ""
    echo -e "${CYAN}=== 관리 명령어 ===${NC}"
    echo -e "${BLUE}n8n-manager${NC}   # 관리 메뉴"
    echo -e "${BLUE}n8n-status${NC}    # 상태 확인"
    echo -e "${BLUE}n8n-logs${NC}      # 로그 보기"
    echo ""
    echo -e "${GREEN}✅ 브라우저에서 http://$EXTERNAL_IP:5678 로 접속하세요!${NC}"
    echo ""
    echo -e "${YELLOW}💡 터미널을 닫아도 n8n은 계속 실행됩니다.${NC}"
    echo -e "${YELLOW}💡 관리가 필요하면 언제든 'n8n-manager' 명령어를 사용하세요.${NC}"
    echo ""
}

# 메인 실행 함수
main() {
    show_intro
    check_server_info
    get_password
    install_n8n
    verify_installation
    create_management_scripts
    show_completion_info
    
    echo -e "${GREEN}🌟 모든 설치가 완료되었습니다! 🌟${NC}"
}

# 인터럽트 핸들링
trap 'echo -e "\n${YELLOW}⚠️  설치가 중단되었습니다.${NC}"; exit 1' INT

# 스크립트 실행
main "$@"