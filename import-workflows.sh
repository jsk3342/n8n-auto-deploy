#!/bin/bash

# n8n 워크플로우 임포트 전용 스크립트
# 사용법: curl -sSL https://raw.githubusercontent.com/jsk3342/n8n-auto-deploy/main/import-workflows.sh | WORKFLOW_TEMPLATE=basic bash

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

echo -e "${BLUE}=== n8n 워크플로우 템플릿 임포트 ===${NC}"
echo -e "${CYAN}기존 n8n에 새로운 워크플로우 템플릿 추가${NC}"
echo ""

# 워크플로우 템플릿 설정
WORKFLOW_TEMPLATE=${WORKFLOW_TEMPLATE:-"basic"}
echo -e "${CYAN}임포트할 템플릿: $WORKFLOW_TEMPLATE${NC}"

# 사용 가능한 템플릿 확인
AVAILABLE_TEMPLATES=("basic" "developer" "marketing" "business")
if [[ ! " ${AVAILABLE_TEMPLATES[@]} " =~ " ${WORKFLOW_TEMPLATE} " ]]; then
    echo -e "${RED}❌ 알 수 없는 템플릿: $WORKFLOW_TEMPLATE${NC}"
    echo -e "${CYAN}사용 가능한 템플릿: ${AVAILABLE_TEMPLATES[*]}${NC}"
    exit 1
fi

# n8n이 실행 중인지 확인
echo -e "${CYAN}n8n 상태 확인 중...${NC}"
if ! docker ps | grep -q n8n; then
    echo -e "${RED}❌ n8n이 실행되지 않았습니다.${NC}"
    echo -e "${YELLOW}다음 명령어로 n8n을 먼저 시작해주세요:${NC}"
    echo "cd ~/n8n && docker-compose up -d"
    exit 1
fi
echo -e "${GREEN}✅ n8n 실행 중${NC}"

# 워크플로우 디렉토리 생성
echo -e "${CYAN}워크플로우 디렉토리 준비...${NC}"
mkdir -p ~/n8n/workflows/$WORKFLOW_TEMPLATE
cd ~/n8n/workflows

# 템플릿 manifest 다운로드
echo -e "${CYAN}템플릿 정보 다운로드 중...${NC}"
if curl -s "${GITHUB_RAW_URL}/workflows/${WORKFLOW_TEMPLATE}/manifest.json" -o ./${WORKFLOW_TEMPLATE}/manifest.json; then
    echo -e "${GREEN}✅ 템플릿 정보 다운로드 완료${NC}"
    
    # 템플릿 정보 출력
    echo ""
    echo -e "${BLUE}📋 템플릿 정보${NC}"
    python3 -c "
import json
try:
    with open('./${WORKFLOW_TEMPLATE}/manifest.json', 'r') as f:
        manifest = json.load(f)
    print(f'이름: {manifest[\"name\"]}')
    print(f'설명: {manifest[\"description\"]}') 
    print(f'난이도: {manifest[\"difficulty\"]}')
    print(f'예상 설정 시간: {manifest[\"estimated_setup_time\"]}')
    print(f'포함된 워크플로우: {len(manifest[\"workflows\"])}개')
except Exception as e:
    print('템플릿 정보를 읽을 수 없습니다.')
" 2>/dev/null
    echo ""
    
    # manifest.json에서 워크플로우 파일 목록 추출
    WORKFLOW_FILES=$(python3 -c "
import json
try:
    with open('./${WORKFLOW_TEMPLATE}/manifest.json', 'r') as f:
        manifest = json.load(f)
    for workflow in manifest['workflows']:
        print(workflow['file'])
except:
    pass
" 2>/dev/null)

    if [[ -z "$WORKFLOW_FILES" ]]; then
        echo -e "${YELLOW}⚠️  워크플로우 목록을 가져올 수 없습니다. 기본 파일들을 다운로드합니다.${NC}"
        WORKFLOW_FILES="ai-secretary-commute.json simple-webhook-test.json daily-weather-report.json api-health-check.json"
    fi

    # 각 워크플로우 파일 다운로드
    echo -e "${CYAN}워크플로우 파일 다운로드 중...${NC}"
    DOWNLOAD_COUNT=0
    TOTAL_COUNT=0
    
    for workflow_file in $WORKFLOW_FILES; do
        ((TOTAL_COUNT++))
        echo -e "${CYAN}  📥 $workflow_file 다운로드 중...${NC}"
        
        if curl -s "${GITHUB_RAW_URL}/workflows/${WORKFLOW_TEMPLATE}/${workflow_file}" -o ./${WORKFLOW_TEMPLATE}/${workflow_file}; then
            echo -e "${GREEN}    ✅ 완료${NC}"
            ((DOWNLOAD_COUNT++))
        else
            echo -e "${YELLOW}    ⚠️  실패${NC}"
        fi
    done
    
    echo ""
    echo -e "${GREEN}📊 다운로드 결과: $DOWNLOAD_COUNT/$TOTAL_COUNT 개 파일 성공${NC}"

else
    echo -e "${RED}❌ 템플릿 정보 다운로드 실패${NC}"
    exit 1
fi

# n8n 서비스 준비 확인
echo ""
echo -e "${CYAN}n8n 서비스 응답 확인 중...${NC}"
MAX_ATTEMPTS=15
ATTEMPT=0
EXTERNAL_IP=$(curl -s http://checkip.amazonaws.com/ 2>/dev/null || echo "localhost")

while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 2>/dev/null)
    if [[ "$HTTP_STATUS" =~ ^(200|401|403)$ ]]; then
        echo -e "${GREEN}✅ n8n 서비스 응답 정상${NC}"
        break
    fi
    echo -e "${CYAN}  ⏳ 대기 중... ($((ATTEMPT + 1))/$MAX_ATTEMPTS)${NC}"
    sleep 2
    ((ATTEMPT++))
done

if [[ $ATTEMPT -eq $MAX_ATTEMPTS ]]; then
    echo -e "${YELLOW}⚠️  n8n 서비스 응답 확인 실패. 수동 임포트가 필요할 수 있습니다.${NC}"
fi

# 임포트 안내
echo ""
echo -e "${BLUE}🎯 워크플로우 임포트 가이드${NC}"
echo ""
echo -e "${YELLOW}📋 단계별 임포트 방법:${NC}"
echo ""
echo -e "${CYAN}1. n8n 웹 인터페이스 접속${NC}"
echo "   🌐 URL: http://$EXTERNAL_IP:5678"
echo ""
echo -e "${CYAN}2. 로그인 후 워크플로우 임포트${NC}"
echo "   • 왼쪽 메뉴에서 'Workflows' 클릭"
echo "   • 우측 상단 '+ Add workflow' → 'Import from file' 선택"
echo ""
echo -e "${CYAN}3. 다음 파일들을 순서대로 임포트:${NC}"

# 워크플로우 목록과 설명 출력
if [[ -f "./${WORKFLOW_TEMPLATE}/manifest.json" ]]; then
    python3 -c "
import json
try:
    with open('./${WORKFLOW_TEMPLATE}/manifest.json', 'r') as f:
        manifest = json.load(f)
    for i, workflow in enumerate(manifest['workflows'], 1):
        print(f'   {i}. {workflow[\"file\"]}')
        print(f'      📝 {workflow[\"name\"]}')
        print(f'      📄 {workflow[\"description\"]}')
        if workflow.get('requirements'):
            print(f'      🔑 필요한 API 키: {', '.join(workflow[\"requirements\"])}')
        print()
except Exception as e:
    print('   워크플로우 목록을 표시할 수 없습니다.')
    print(f'   📁 파일 위치: ~/n8n/workflows/{WORKFLOW_TEMPLATE}/')
" 2>/dev/null
else
    echo "   📁 파일 위치: ~/n8n/workflows/${WORKFLOW_TEMPLATE}/"
fi

echo -e "${CYAN}4. 각 워크플로우 활성화${NC}"
echo "   • 임포트한 워크플로우에서 우측 상단 'Active' 토글 켜기"
echo "   • 필요한 경우 Credentials(인증 정보) 설정"
echo ""

# API 설정 안내
echo -e "${YELLOW}🔑 API 키 설정이 필요한 경우:${NC}"
echo ""
echo -e "${CYAN}Settings → Credentials → Add Credential에서 설정${NC}"
echo "• OpenAI API (AI 기능용)"
echo "• 네이버 클라우드 플랫폼 (지도 API용)"  
echo "• 카카오톡 API (메시지 전송용)"
echo "• OpenWeatherMap API (날씨 정보용)"
echo ""

# 파일 위치 정보
echo -e "${BLUE}📁 다운로드된 파일 위치${NC}"
echo "디렉토리: ~/n8n/workflows/${WORKFLOW_TEMPLATE}/"
echo ""
echo "파일 목록 확인:"
echo "ls -la ~/n8n/workflows/${WORKFLOW_TEMPLATE}/"
echo ""

# 추가 템플릿 안내
echo -e "${CYAN}💡 추가 템플릿 설치${NC}"
echo "다른 템플릿도 설치하려면:"
echo ""
for template in "${AVAILABLE_TEMPLATES[@]}"; do
    if [[ "$template" != "$WORKFLOW_TEMPLATE" ]]; then
        echo "curl -sSL ${GITHUB_RAW_URL}/import-workflows.sh | WORKFLOW_TEMPLATE=$template bash"
    fi
done
echo ""

# 완료 메시지
echo -e "${GREEN}🎉 워크플로우 템플릿 다운로드 완료! 🎉${NC}"
echo ""
echo -e "${BLUE}이제 n8n 웹 인터페이스에서 워크플로우를 임포트하고${NC}"
echo -e "${BLUE}각각을 Active 상태로 만들어 자동화를 시작하세요! 🚀${NC}"