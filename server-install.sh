#!/bin/bash

# n8n + 워크플로우 템플릿 자동 설치 스크립트
# 사용법: 
# curl -sSL https://raw.githubusercontent.com/jsk3342/n8n-auto-deploy/main/server-install.sh | N8N_PASSWORD=mypass123 WORKFLOW_TEMPLATE=basic bash

set -e

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# GitHub 저장소 설정
GITHUB_REPO="jsk3342/n8n-auto-deploy"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main"

clear
echo -e "${BLUE}"
echo "  ███╗   ██╗ █████╗ ███╗   ██╗"
echo "  ████╗  ██║██╔══██╗████╗  ██║"
echo "  ██╔██╗ ██║╚█████╔╝██╔██╗ ██║"
echo "  ██║╚██╗██║██╔══██╗██║╚██╗██║"
echo "  ██║ ╚████║╚█████╔╝██║ ╚████║"
echo "  ╚═╝  ╚═══╝ ╚════╝ ╚═╝  ╚═══╝"
echo -e "${NC}"
echo -e "${CYAN}=== n8n + 워크플로우 템플릿 자동 설치 ===${NC}"
echo -e "${YELLOW}완전 자동화된 설치 + 즉시 사용 가능한 워크플로우${NC}"
echo ""

# 외부 IP 확인
echo -e "${CYAN}외부 IP 확인 중...${NC}"
EXTERNAL_IP=$(curl -s http://checkip.amazonaws.com/)
echo -e "${GREEN}외부 IP: $EXTERNAL_IP${NC}"
echo ""

# 워크플로우 템플릿 설정
WORKFLOW_TEMPLATE=${WORKFLOW_TEMPLATE:-"basic"}
echo -e "${CYAN}선택된 워크플로우 템플릿: $WORKFLOW_TEMPLATE${NC}"

# 사용 가능한 템플릿 확인
AVAILABLE_TEMPLATES=("basic" "developer" "marketing" "business")
if [[ ! " ${AVAILABLE_TEMPLATES[@]} " =~ " ${WORKFLOW_TEMPLATE} " ]]; then
    echo -e "${YELLOW}⚠️  알 수 없는 템플릿: $WORKFLOW_TEMPLATE${NC}"
    echo -e "${CYAN}사용 가능한 템플릿: ${AVAILABLE_TEMPLATES[*]}${NC}"
    echo -e "${CYAN}기본 템플릿(basic)으로 설정합니다.${NC}"
    WORKFLOW_TEMPLATE="basic"
fi
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
    sudo usermod -aG docker ubuntu
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
mkdir -p ~/n8n ~/n8n/workflows
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
      - ./workflows:/workflows
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

# 워크플로우 템플릿 다운로드
echo -e "${CYAN}📥 워크플로우 템플릿 다운로드 중...${NC}"

# 템플릿 manifest 다운로드
if curl -s "${GITHUB_RAW_URL}/workflows/${WORKFLOW_TEMPLATE}/manifest.json" -o ~/n8n/workflows/manifest.json; then
    echo -e "${GREEN}✅ 템플릿 정보 다운로드 완료${NC}"
    
    # manifest.json에서 워크플로우 파일 목록 추출
    WORKFLOW_FILES=$(python3 -c "
import json
with open('~/n8n/workflows/manifest.json', 'r') as f:
    manifest = json.load(f)
    for workflow in manifest['workflows']:
        print(workflow['file'])
" 2>/dev/null || echo "ai-secretary-commute.json simple-webhook-test.json daily-weather-report.json api-health-check.json")

    # 각 워크플로우 파일 다운로드
    for workflow_file in $WORKFLOW_FILES; do
        echo -e "${CYAN}  └ $workflow_file 다운로드 중...${NC}"
        if curl -s "${GITHUB_RAW_URL}/workflows/${WORKFLOW_TEMPLATE}/${workflow_file}" -o ~/n8n/workflows/${workflow_file}; then
            echo -e "${GREEN}    ✅ 완료${NC}"
        else
            echo -e "${YELLOW}    ⚠️  실패 (계속 진행)${NC}"
        fi
    done
else
    echo -e "${YELLOW}⚠️  템플릿 다운로드 실패 - 기본 워크플로우 생성${NC}"
    
    # 기본 웹훅 테스트 워크플로우 생성
    cat > ~/n8n/workflows/simple-webhook-test.json << 'EOF'
{
  "name": "Simple Webhook Test",
  "nodes": [
    {
      "parameters": {
        "httpMethod": "POST",
        "path": "test"
      },
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 1.1,
      "position": [240, 300],
      "id": "webhook-test-1",
      "name": "Webhook"
    },
    {
      "parameters": {
        "values": {
          "string": [
            {
              "name": "message",
              "value": "Hello from n8n! 🚀"
            },
            {
              "name": "timestamp", 
              "value": "={{ new Date().toISOString() }}"
            }
          ]
        }
      },
      "type": "n8n-nodes-base.set",
      "typeVersion": 3.4,
      "position": [460, 300],
      "id": "set-test-1",
      "name": "Set Response"
    }
  ],
  "connections": {
    "Webhook": {
      "main": [
        [
          {
            "node": "Set Response",
            "type": "main",
            "index": 0
          }
        ]
      ]
    }
  },
  "active": false,
  "settings": {
    "executionOrder": "v1"
  }
}
EOF
fi

echo -e "${GREEN}✅ 워크플로우 템플릿 준비 완료${NC}"

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

# 워크플로우 자동 임포트 스크립트 생성
echo -e "${CYAN}🛠️  워크플로우 임포트 도구 생성...${NC}"
cat > ~/import-workflows.sh << 'SCRIPT_EOF'
#!/bin/bash

# n8n 워크플로우 자동 임포트 스크립트

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}=== n8n 워크플로우 자동 임포트 ===${NC}"
echo ""

# n8n이 실행 중인지 확인
if ! docker ps | grep -q n8n; then
    echo -e "${YELLOW}❌ n8n이 실행되지 않았습니다. 먼저 n8n을 시작해주세요.${NC}"
    echo "실행 명령어: cd ~/n8n && docker-compose up -d"
    exit 1
fi

# n8n 서비스 준비 대기
echo -e "${CYAN}n8n 서비스 준비 확인 중...${NC}"
MAX_ATTEMPTS=30
ATTEMPT=0

while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 2>/dev/null)
    if [[ "$HTTP_STATUS" =~ ^(200|401|403)$ ]]; then
        echo -e "${GREEN}✅ n8n 서비스 준비 완료${NC}"
        break
    fi
    echo -e "${CYAN}  대기 중... ($((ATTEMPT + 1))/$MAX_ATTEMPTS)${NC}"
    sleep 2
    ((ATTEMPT++))
done

if [[ $ATTEMPT -eq $MAX_ATTEMPTS ]]; then
    echo -e "${YELLOW}⚠️  n8n 서비스 응답 확인 실패. 수동으로 워크플로우를 임포트해주세요.${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}📥 워크플로우 임포트 안내${NC}"
echo ""
echo -e "${YELLOW}다음 단계를 따라 워크플로우를 임포트하세요:${NC}"
echo ""
echo "1. 브라우저에서 n8n 접속 후 로그인"
echo "2. 왼쪽 메뉴에서 'Workflows' 클릭"  
echo "3. 우측 상단 '...' 메뉴 → 'Import from file' 선택"
echo "4. 다음 파일들을 순서대로 임포트:"
echo ""

# 워크플로우 파일 목록 출력
WORKFLOW_DIR="~/n8n/workflows"
if [[ -f "$WORKFLOW_DIR/manifest.json" ]]; then
    echo -e "${CYAN}📋 사용 가능한 워크플로우:${NC}"
    python3 -c "
import json
try:
    with open('$WORKFLOW_DIR/manifest.json', 'r') as f:
        manifest = json.load(f)
    for i, workflow in enumerate(manifest['workflows'], 1):
        print(f'   {i}. {workflow[\"file\"]} - {workflow[\"name\"]}')
except:
    pass
" 2>/dev/null
else
    echo -e "${CYAN}📋 기본 워크플로우:${NC}"
    find ~/n8n/workflows -name "*.json" -not -name "manifest.json" | while read file; do
        filename=$(basename "$file")
        echo "   • $filename"
    done
fi

echo ""
echo -e "${YELLOW}💡 팁: 각 워크플로우를 임포트한 후 'Active' 토글을 켜야 동작합니다!${NC}"
echo ""

# 워크플로우 파일 위치 안내
echo -e "${CYAN}📁 워크플로우 파일 위치: ~/n8n/workflows/${NC}"
echo -e "${CYAN}🌐 n8n 접속 URL: http://$(curl -s http://checkip.amazonaws.com/):5678${NC}"
echo ""
SCRIPT_EOF

chmod +x ~/import-workflows.sh

# 관리 도구 생성
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
    echo "7) 워크플로우 임포트 안내"
    echo "8) 백업"
    echo "9) 종료"
    echo -n "선택 (1-9): "
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
            ~/import-workflows.sh
            ;;
        8)
            echo -e "${CYAN}백업 생성 중...${NC}"
            BACKUP_NAME="n8n-backup-$(date +%Y%m%d-%H%M%S).json"
            if docker exec n8n n8n export:all --output=/tmp/$BACKUP_NAME 2>/dev/null; then
                docker cp n8n:/tmp/$BACKUP_NAME ./$BACKUP_NAME 2>/dev/null
                echo -e "${GREEN}✅ 백업 완료: $BACKUP_NAME${NC}"
            else
                echo -e "${YELLOW}⚠️  백업 실패${NC}"
            fi
            ;;
        9) 
            echo -e "${GREEN}👋 관리 도구를 종료합니다${NC}"
            break
            ;;
        *) 
            echo -e "${YELLOW}1-9 중에서 선택해주세요${NC}"
            ;;
    esac
    echo ""
done
MANAGER_EOF

chmod +x ~/n8n-manager
echo "alias n8n-manager='~/n8n-manager'" >> ~/.bashrc
echo "alias import-workflows='~/import-workflows.sh'" >> ~/.bashrc
echo -e "${GREEN}✅ 완료${NC}"

# 접속 정보 파일 생성
cat > ~/n8n-info.txt << EOF
n8n + 워크플로우 템플릿 설치 완료
===================================

접속 정보:
URL: http://$EXTERNAL_IP:5678
Username: admin
Password: $N8N_PASSWORD

워크플로우 템플릿: $WORKFLOW_TEMPLATE
워크플로우 파일 위치: ~/n8n/workflows/

관리 명령어:
- n8n-manager: 관리 메뉴
- import-workflows: 워크플로우 임포트 안내

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
echo -e "${GREEN}🎉 n8n + 워크플로우 템플릿 설치 완료! 🎉${NC}"
echo ""
echo -e "${YELLOW}=== 📱 접속 정보 ===${NC}"
echo -e "${CYAN}🌐 URL: http://$EXTERNAL_IP:5678${NC}"
echo -e "${CYAN}👤 사용자명: admin${NC}"
echo -e "${CYAN}🔐 비밀번호: $N8N_PASSWORD${NC}"
echo ""
echo -e "${YELLOW}=== 📦 설치된 템플릿 ===${NC}"
echo -e "${CYAN}📂 템플릿: $WORKFLOW_TEMPLATE${NC}"
echo -e "${CYAN}📁 위치: ~/n8n/workflows/${NC}"
echo ""
echo -e "${YELLOW}=== 🚀 다음 단계 ===${NC}"
echo -e "${CYAN}1. 브라우저에서 http://$EXTERNAL_IP:5678 접속${NC}"
echo -e "${CYAN}2. admin / $N8N_PASSWORD 로 로그인${NC}"
echo -e "${CYAN}3. 'import-workflows' 명령어로 워크플로우 임포트 안내 확인${NC}"
echo -e "${CYAN}4. 워크플로우를 임포트하고 Active 상태로 변경${NC}"
echo ""
echo -e "${YELLOW}=== ⚙️  관리 명령어 ===${NC}"
echo -e "${CYAN}n8n-manager${NC} - 관리 메뉴"
echo -e "${CYAN}import-workflows${NC} - 워크플로우 임포트 안내"
echo ""

if [[ "$HTTP_STATUS" =~ ^(200|401|403)$ ]]; then
    echo -e "${GREEN}🎊 성공! 이제 브라우저에서 접속하여 워크플로우를 사용하세요! 🎊${NC}"
else
    echo -e "${YELLOW}⏳ n8n이 아직 시작 중일 수 있습니다. 1-2분 후 다시 접속해보세요.${NC}"
fi

echo ""
echo -e "${BLUE}💡 터미널을 닫아도 n8n은 계속 실행됩니다.${NC}"
echo -e "${BLUE}🚀 즐거운 자동화 라이프 되세요! 🚀${NC}"