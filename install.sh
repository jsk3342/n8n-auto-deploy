#!/bin/bash

# n8n 간단 설치 스크립트 (AWS 클릭 방식)
# 사전 준비: EC2 생성, 탄력적 IP 할당, 보안그룹 포트 추가
# 사용법: curl -sSL https://raw.githubusercontent.com/jsk3342/n8n-auto-deploy/main/install.sh | bash

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
    echo -e "${CYAN}=== n8n 자동화 플랫폼 간편 설치 ===${NC}"
    echo -e "${YELLOW}AWS EC2 + Docker 기반 원클릭 배포${NC}"
    echo ""
    echo -e "${GREEN}✅ 보안 키페어 방식 (Access Key 불필요)${NC}"
    echo -e "${GREEN}✅ Docker + n8n 자동 설치${NC}"
    echo -e "${GREEN}✅ 프리티어 최적화 설정${NC}"
    echo -e "${GREEN}✅ 즉시 사용 가능한 환경 구성${NC}"
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

# 사전 준비 확인
check_prerequisites() {
    echo -e "${CYAN}=== 사전 준비사항 확인 ===${NC}"
    echo ""
    echo -e "${YELLOW}다음 작업들이 AWS 콘솔에서 완료되었는지 확인하세요:${NC}"
    echo ""
    echo -e "${BLUE}1. EC2 인스턴스 생성${NC}"
    echo "   • AMI: Ubuntu 22.04 LTS"
    echo "   • 타입: t2.micro (프리티어)"
    echo "   • 키페어: 생성 후 .pem 파일 다운로드"
    echo ""
    echo -e "${BLUE}2. 탄력적 IP 할당 및 연결${NC}"
    echo "   • EC2 → 네트워크 및 보안 → 탄력적 IP"
    echo "   • '탄력적 IP 주소 할당' → 인스턴스에 연결"
    echo ""
    echo -e "${BLUE}3. 보안그룹 포트 추가${NC}"
    echo "   • EC2 → 보안그룹 → 인바운드 규칙 편집"
    echo "   • 유형: 사용자 지정 TCP, 포트: 5678, 소스: 내 IP"
    echo ""
    
    read -p "위 작업들이 모두 완료되었습니까? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        warn_msg "사전 준비를 완료한 후 다시 실행해주세요."
        exit 1
    fi
    
    success_msg "사전 준비 확인 완료"
    echo ""
}

# 사용자 정보 입력
get_user_input() {
    echo -e "${CYAN}=== 연결 정보 입력 ===${NC}"
    echo ""
    
    # 탄력적 IP 주소
    while true; do
        read -p "탄력적 IP 주소: " ELASTIC_IP
        # IP 형식 검증
        if [[ $ELASTIC_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            # 각 옥텟이 0-255 범위인지 확인
            valid=true
            IFS='.' read -ra ADDR <<< "$ELASTIC_IP"
            for i in "${ADDR[@]}"; do
                if [[ $i -lt 0 || $i -gt 255 ]]; then
                    valid=false
                    break
                fi
            done
            if $valid; then
                break
            fi
        fi
        warn_msg "올바른 IP 주소 형식이 아닙니다. (예: 13.54.40.102)"
    done
    
    # 키페어 파일 경로
    while true; do
        read -p "키페어(.pem) 파일 경로: " KEY_PATH
        # 물결표 확장
        KEY_PATH="${KEY_PATH/#\~/$HOME}"
        if [[ -f "$KEY_PATH" ]]; then
            # 권한 확인 및 수정
            chmod 400 "$KEY_PATH"
            break
        else
            warn_msg "파일을 찾을 수 없습니다: $KEY_PATH"
            echo "   힌트: 전체 경로를 입력하세요. (예: /Users/username/Downloads/my-key.pem)"
        fi
    done
    
    # n8n 관리자 비밀번호
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
    
    echo ""
    success_msg "모든 정보 입력 완료"
}

# SSH 연결 테스트
test_ssh_connection() {
    info_msg "SSH 연결 테스트 중..."
    
    # SSH 연결 테스트 (최대 30초 대기)
    local max_attempts=6
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if ssh -i "$KEY_PATH" -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes ubuntu@"$ELASTIC_IP" "echo 'SSH 연결 성공'" &> /dev/null; then
            success_msg "SSH 연결 테스트 성공"
            return 0
        fi
        
        warn_msg "SSH 연결 시도 $attempt/$max_attempts 실패... 5초 후 재시도"
        if [[ $attempt -eq 3 ]]; then
            echo ""
            echo -e "${YELLOW}연결에 시간이 걸리고 있습니다. 다음을 확인해주세요:${NC}"
            echo "• 탄력적 IP가 인스턴스에 올바르게 연결되었는지"
            echo "• 보안그룹에서 SSH(22번 포트)가 허용되었는지"
            echo "• 키페어 파일 경로가 올바른지"
            echo ""
        fi
        sleep 5
        ((attempt++))
    done
    
    error_exit "SSH 연결에 실패했습니다. 설정을 다시 확인해주세요."
}

# 서버 정보 확인
check_server_info() {
    info_msg "서버 정보 확인 중..."
    
    SERVER_INFO=$(ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$ELASTIC_IP" << 'EOF'
echo "OS: $(lsb_release -d | cut -f2)"
echo "Architecture: $(uname -m)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $2}')"
echo "CPU Cores: $(nproc)"
EOF
)
    
    echo -e "${CYAN}서버 사양:${NC}"
    echo "$SERVER_INFO" | sed 's/^/  /'
    echo ""
    
    success_msg "서버 정보 확인 완료"
}

# 서버에 n8n 설치
install_n8n() {
    info_msg "서버에 n8n 설치 중... (약 3-5분 소요)"
    echo ""
    
    ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$ELASTIC_IP" << EOF
        set -e
        
        echo "🔄 시스템 업데이트 중..."
        sudo apt update -qq && sudo apt upgrade -y -qq
        
        echo "🐳 Docker 설치 중..."
        if ! command -v docker &> /dev/null; then
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh > /dev/null 2>&1
            sudo usermod -aG docker ubuntu
            rm get-docker.sh
            echo "   ✅ Docker 설치 완료"
        else
            echo "   ✅ Docker가 이미 설치되어 있습니다"
        fi
        
        echo "📦 Docker Compose 설치 중..."
        if ! command -v docker-compose &> /dev/null; then
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            echo "   ✅ Docker Compose 설치 완료"
        else
            echo "   ✅ Docker Compose가 이미 설치되어 있습니다"
        fi
        
        echo "📁 n8n 디렉토리 설정 중..."
        mkdir -p ~/n8n
        cd ~/n8n
        
        echo "⚙️  n8n 환경 설정 중..."
        cat > .env << 'EOL'
# n8n 기본 설정
N8N_HOST=$ELASTIC_IP
N8N_PORT=5678
N8N_PROTOCOL=http

# 인증 설정
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD

# 웹훅 URL 설정
WEBHOOK_TUNNEL_URL=http://$ELASTIC_IP:5678

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

        echo "🔥 방화벽 설정 중..."
        sudo ufw --force enable > /dev/null 2>&1
        sudo ufw allow ssh > /dev/null 2>&1
        sudo ufw allow 5678 > /dev/null 2>&1
        echo "   ✅ 방화벽 설정 완료"
        
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
            echo "   ✅ n8n 컨테이너가 실행 중입니다"
        else
            echo "   ⚠️  n8n 컨테이너 상태를 확인해주세요"
        fi
        
        echo ""
        echo "🎉 설치 완료! 🎉"
EOF

    if [[ $? -eq 0 ]]; then
        success_msg "n8n 설치 완료"
    else
        error_exit "n8n 설치 중 오류가 발생했습니다."
    fi
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
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ELASTIC_IP:5678" 2>/dev/null)
        
        if [[ "$HTTP_STATUS" =~ ^(200|401|403)$ ]]; then
            success_msg "n8n 서비스가 정상적으로 실행 중입니다"
            return 0
        fi
        
        if [[ $attempt -eq 6 ]]; then
            warn_msg "서비스 시작에 시간이 걸리고 있습니다..."
            echo "   Docker가 이미지를 다운로드하고 있을 수 있습니다."
        fi
        
        warn_msg "n8n 서비스 확인 시도 $attempt/$max_attempts (HTTP: $HTTP_STATUS)... 10초 후 재시도"
        sleep 10
        ((attempt++))
    done
    
    warn_msg "n8n 서비스 확인에 실패했습니다."
    echo "   수동으로 확인: http://$ELASTIC_IP:5678"
}

# 관리 스크립트 생성
create_management_scripts() {
    info_msg "관리 도구 설치 중..."
    
    ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$ELASTIC_IP" << 'EOF'
        # n8n 관리 스크립트 생성
        cat > ~/n8n-manager.sh << 'SCRIPT_EOF'
#!/bin/bash

# n8n 관리 스크립트

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    echo "9) 종료"
    echo -n "선택: "
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
EOF

    success_msg "관리 도구 설치 완료"
}

# 최종 정보 출력
show_completion_info() {
    echo ""
    echo -e "${GREEN}🎉 n8n 설치가 완료되었습니다! 🎉${NC}"
    echo ""
    echo -e "${CYAN}=== 접속 정보 ===${NC}"
    echo -e "${YELLOW}n8n URL:${NC} http://$ELASTIC_IP:5678"
    echo -e "${YELLOW}사용자명:${NC} admin"
    echo -e "${YELLOW}비밀번호:${NC} [설정한 비밀번호]"
    echo ""
    echo -e "${CYAN}=== 서버 관리 ===${NC}"
    echo -e "${YELLOW}SSH 접속:${NC} ssh -i $KEY_PATH ubuntu@$ELASTIC_IP"
    echo -e "${YELLOW}관리 도구:${NC} ssh 접속 후 'n8n-manager' 실행"
    echo ""
    echo -e "${CYAN}=== 웹훅 URL 형식 ===${NC}"
    echo -e "${YELLOW}기본 웹훅:${NC} http://$ELASTIC_IP:5678/webhook/워크플로우명"
    echo ""
    echo -e "${CYAN}=== 빠른 명령어 (SSH 접속 후 사용) ===${NC}"
    echo -e "${BLUE}n8n-status${NC}    # 상태 확인"
    echo -e "${BLUE}n8n-logs${NC}      # 로그 보기"
    echo -e "${BLUE}n8n-manager${NC}   # 관리 메뉴"
    echo ""
    echo -e "${GREEN}✅ 브라우저에서 http://$ELASTIC_IP:5678 로 접속하세요!${NC}"
    echo ""
    
    # 정보를 파일로 저장
    cat > n8n-connection-info.txt << EOF
n8n 자동화 플랫폼 설치 완료
============================

🌐 접속 정보:
- URL: http://$ELASTIC_IP:5678
- 사용자명: admin
- 비밀번호: [설정한 비밀번호]

🖥️  서버 관리:
- SSH 접속: ssh -i $KEY_PATH ubuntu@$ELASTIC_IP
- 관리 도구: n8n-manager
- 상태 확인: n8n-status
- 로그 보기: n8n-logs

🔗 웹훅 URL:
- 형식: http://$ELASTIC_IP:5678/webhook/[워크플로우명]
- 예시: http://$ELASTIC_IP:5678/webhook/slack-notify

📅 설치 일시: $(date '+%Y년 %m월 %d일 %H:%M:%S')

📚 추가 정보:
- n8n 공식 문서: https://docs.n8n.io
- 커뮤니티: https://community.n8n.io
EOF
    
    echo -e "${CYAN}📄 접속 정보가 'n8n-connection-info.txt' 파일에 저장되었습니다.${NC}"
    echo ""
    echo -e "${BLUE}🚀 이제 n8n으로 멋진 자동화를 만들어보세요! 🚀${NC}"
}

# 메인 실행 함수
main() {
    show_intro
    check_prerequisites
    get_user_input
    test_ssh_connection
    check_server_info
    install_n8n
    verify_installation
    create_management_scripts
    show_completion_info
    
    echo -e "${GREEN}🌟 모든 설치가 완료되었습니다! 즐거운 자동화 라이프 되세요! 🌟${NC}"
}

# 인터럽트 핸들링
trap 'echo -e "\n${YELLOW}⚠️  설치가 중단되었습니다.${NC}"; exit 1' INT

# 스크립트 실행
main "$@"