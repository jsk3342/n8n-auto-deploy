#!/bin/bash

# n8n 자동 설정 스크립트
# 사전 요구사항: EC2 인스턴스 생성 및 키페어(.pem) 파일 준비
# 사용법: curl -sSL https://raw.githubusercontent.com/your-username/n8n-auto-deploy/main/install.sh | bash

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
    echo -e "${CYAN}=== n8n 자동화 플랫폼 설치 스크립트 ===${NC}"
    echo -e "${YELLOW}AWS 프리티어용 원클릭 배포 시스템${NC}"
    echo ""
    echo -e "${GREEN}✅ 탄력적 IP 자동 할당${NC}"
    echo -e "${GREEN}✅ 보안그룹 자동 설정${NC}"
    echo -e "${GREEN}✅ Docker + n8n 자동 설치${NC}"
    echo -e "${GREEN}✅ 완전 자동화된 환경 구성${NC}"
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

# AWS CLI 설치 확인
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        info_msg "AWS CLI를 설치하는 중..."
        
        # 운영체제 확인
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip awscliv2.zip
            sudo ./aws/install
            rm -rf awscliv2.zip aws/
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew &> /dev/null; then
                brew install awscli
            else
                error_exit "macOS에서는 Homebrew를 먼저 설치해주세요: https://brew.sh"
            fi
        else
            error_exit "지원하지 않는 운영체제입니다. 수동으로 AWS CLI를 설치해주세요."
        fi
        
        success_msg "AWS CLI 설치 완료"
    else
        success_msg "AWS CLI가 이미 설치되어 있습니다"
    fi
}

# 사용자 정보 입력
get_user_input() {
    echo -e "${CYAN}=== 설정 정보 입력 ===${NC}"
    echo ""
    
    # EC2 인스턴스 ID
    while true; do
        read -p "EC2 인스턴스 ID (i-로 시작): " INSTANCE_ID
        if [[ $INSTANCE_ID =~ ^i-[0-9a-f]{8,17}$ ]]; then
            break
        else
            warn_msg "올바른 인스턴스 ID 형식이 아닙니다. (예: i-1234567890abcdef0)"
        fi
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
        fi
    done
    
    # AWS 자격증명
    echo ""
    echo -e "${YELLOW}AWS 자격증명 정보를 입력하세요:${NC}"
    read -p "AWS Access Key ID: " AWS_ACCESS_KEY
    read -s -p "AWS Secret Access Key: " AWS_SECRET_KEY
    echo ""
    
    # AWS 리전
    read -p "AWS 리전 (기본값: ap-northeast-2): " AWS_REGION
    AWS_REGION=${AWS_REGION:-ap-northeast-2}
    
    # n8n 관리자 비밀번호
    echo ""
    while true; do
        read -s -p "n8n 관리자 비밀번호 (8자 이상): " N8N_PASSWORD
        echo ""
        if [[ ${#N8N_PASSWORD} -ge 8 ]]; then
            break
        else
            warn_msg "비밀번호는 8자 이상이어야 합니다."
        fi
    done
    
    echo ""
    success_msg "모든 정보 입력 완료"
}

# AWS 자격증명 설정
setup_aws_credentials() {
    info_msg "AWS 자격증명 설정 중..."
    
    export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_KEY"
    export AWS_DEFAULT_REGION="$AWS_REGION"
    
    # 자격증명 테스트
    if ! aws sts get-caller-identity &> /dev/null; then
        error_exit "AWS 자격증명이 올바르지 않습니다."
    fi
    
    success_msg "AWS 자격증명 설정 완료"
}

# 현재 공인 IP 확인
get_my_ip() {
    info_msg "현재 공인 IP 확인 중..."
    
    MY_IP=$(curl -s https://checkip.amazonaws.com/ || curl -s https://ipinfo.io/ip || curl -s https://ifconfig.me)
    
    if [[ -z "$MY_IP" ]]; then
        error_exit "공인 IP를 확인할 수 없습니다."
    fi
    
    success_msg "현재 공인 IP: $MY_IP"
}

# 인스턴스 정보 확인
check_instance() {
    info_msg "EC2 인스턴스 정보 확인 중..."
    
    INSTANCE_INFO=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0]' 2>/dev/null)
    
    if [[ -z "$INSTANCE_INFO" || "$INSTANCE_INFO" == "null" ]]; then
        error_exit "인스턴스 $INSTANCE_ID를 찾을 수 없습니다."
    fi
    
    INSTANCE_STATE=$(echo "$INSTANCE_INFO" | jq -r '.State.Name')
    VPC_ID=$(echo "$INSTANCE_INFO" | jq -r '.VpcId')
    SUBNET_ID=$(echo "$INSTANCE_INFO" | jq -r '.SubnetId')
    SECURITY_GROUPS=$(echo "$INSTANCE_INFO" | jq -r '.SecurityGroups[].GroupId' | tr '\n' ' ')
    
    if [[ "$INSTANCE_STATE" != "running" ]]; then
        error_exit "인스턴스가 실행 중이 아닙니다. 현재 상태: $INSTANCE_STATE"
    fi
    
    success_msg "인스턴스 확인 완료 (상태: $INSTANCE_STATE)"
}

# 탄력적 IP 할당 및 연결
setup_elastic_ip() {
    info_msg "탄력적 IP 할당 중..."
    
    # 탄력적 IP 할당
    ALLOCATION_RESULT=$(aws ec2 allocate-address --domain vpc --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=n8n-elastic-ip}]')
    ALLOCATION_ID=$(echo "$ALLOCATION_RESULT" | jq -r '.AllocationId')
    ELASTIC_IP=$(echo "$ALLOCATION_RESULT" | jq -r '.PublicIp')
    
    if [[ -z "$ELASTIC_IP" || "$ELASTIC_IP" == "null" ]]; then
        error_exit "탄력적 IP 할당에 실패했습니다."
    fi
    
    success_msg "탄력적 IP 할당 완료: $ELASTIC_IP"
    
    # 인스턴스에 연결
    info_msg "탄력적 IP를 인스턴스에 연결 중..."
    
    aws ec2 associate-address --instance-id "$INSTANCE_ID" --allocation-id "$ALLOCATION_ID"
    
    success_msg "탄력적 IP 연결 완료"
    
    # 연결 확인을 위해 잠시 대기
    sleep 10
}

# 보안그룹 설정
setup_security_group() {
    info_msg "n8n 전용 보안그룹 생성 중..."
    
    # 보안그룹 생성
    SECURITY_GROUP_RESULT=$(aws ec2 create-security-group \
        --group-name "n8n-security-group" \
        --description "n8n automation platform security group" \
        --vpc-id "$VPC_ID" \
        --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=n8n-security-group}]')
    
    N8N_SECURITY_GROUP_ID=$(echo "$SECURITY_GROUP_RESULT" | jq -r '.GroupId')
    
    if [[ -z "$N8N_SECURITY_GROUP_ID" || "$N8N_SECURITY_GROUP_ID" == "null" ]]; then
        error_exit "보안그룹 생성에 실패했습니다."
    fi
    
    success_msg "보안그룹 생성 완료: $N8N_SECURITY_GROUP_ID"
    
    # 인바운드 규칙 추가
    info_msg "보안그룹 규칙 설정 중..."
    
    # SSH (본인 IP만)
    aws ec2 authorize-security-group-ingress \
        --group-id "$N8N_SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 22 \
        --cidr "${MY_IP}/32" \
        --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=n8n-ssh-rule}]'
    
    # n8n (본인 IP만)
    aws ec2 authorize-security-group-ingress \
        --group-id "$N8N_SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 5678 \
        --cidr "${MY_IP}/32" \
        --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=n8n-web-rule}]'
    
    # HTTPS (선택적 - 나중에 SSL 설정시)
    aws ec2 authorize-security-group-ingress \
        --group-id "$N8N_SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 443 \
        --cidr "${MY_IP}/32" \
        --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=n8n-https-rule}]' 2>/dev/null || true
    
    success_msg "보안그룹 규칙 설정 완료"
    
    # 인스턴스에 보안그룹 적용
    info_msg "인스턴스에 보안그룹 적용 중..."
    
    aws ec2 modify-instance-attribute \
        --instance-id "$INSTANCE_ID" \
        --groups $SECURITY_GROUPS $N8N_SECURITY_GROUP_ID
    
    success_msg "보안그룹 적용 완료"
}

# SSH 연결 테스트
test_ssh_connection() {
    info_msg "SSH 연결 테스트 중..."
    
    # SSH 연결 테스트 (최대 30초 대기)
    local max_attempts=6
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if ssh -i "$KEY_PATH" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$ELASTIC_IP" "echo 'SSH 연결 성공'" &> /dev/null; then
            success_msg "SSH 연결 테스트 성공"
            return 0
        fi
        
        warn_msg "SSH 연결 시도 $attempt/$max_attempts 실패... 5초 후 재시도"
        sleep 5
        ((attempt++))
    done
    
    error_exit "SSH 연결에 실패했습니다. 보안그룹과 키페어를 확인해주세요."
}

# 서버에 n8n 설치
install_n8n() {
    info_msg "서버에 n8n 설치 중... (약 3-5분 소요)"
    
    ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$ELASTIC_IP" << EOF
        set -e
        
        # 시스템 업데이트
        echo "시스템 업데이트 중..."
        sudo apt update && sudo apt upgrade -y
        
        # Docker 설치
        echo "Docker 설치 중..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker ubuntu
        rm get-docker.sh
        
        # Docker Compose 설치
        echo "Docker Compose 설치 중..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        # n8n 디렉토리 생성
        mkdir -p ~/n8n
        cd ~/n8n
        
        # 환경 설정 파일 생성
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
EOL

        # Docker Compose 파일 생성
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
    
    # 프리티어 최적화
    mem_limit: 512m
    cpus: '0.8'
    
    # 로그 관리
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  n8n_data:
    driver: local
EOL

        # UFW 방화벽 설정
        echo "방화벽 설정 중..."
        sudo ufw --force enable
        sudo ufw allow ssh
        sudo ufw allow from $MY_IP to any port 5678
        
        # Docker 그룹 적용을 위해 newgrp 사용
        echo "n8n 시작 중..."
        sudo -u ubuntu newgrp docker << 'DOCKER_EOF'
            cd ~/n8n
            docker-compose up -d
DOCKER_EOF

        echo "설치 완료!"
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
    
    # 잠시 대기 (서비스 시작 시간)
    sleep 30
    
    # HTTP 상태 확인
    local max_attempts=10
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://$ELASTIC_IP:5678" | grep -q "200\|401"; then
            success_msg "n8n 서비스가 정상적으로 실행 중입니다"
            return 0
        fi
        
        warn_msg "n8n 서비스 확인 시도 $attempt/$max_attempts... 10초 후 재시도"
        sleep 10
        ((attempt++))
    done
    
    warn_msg "n8n 서비스 확인에 실패했습니다. 수동으로 확인해주세요."
}

# 최종 정보 출력
show_completion_info() {
    echo ""
    echo -e "${GREEN}🎉 n8n 설치가 완료되었습니다! 🎉${NC}"
    echo ""
    echo -e "${CYAN}=== 접속 정보 ===${NC}"
    echo -e "${YELLOW}n8n URL:${NC} http://$ELASTIC_IP:5678"
    echo -e "${YELLOW}사용자명:${NC} admin"
    echo -e "${YELLOW}비밀번호:${NC} $N8N_PASSWORD"
    echo ""
    echo -e "${CYAN}=== 서버 정보 ===${NC}"
    echo -e "${YELLOW}인스턴스 ID:${NC} $INSTANCE_ID"
    echo -e "${YELLOW}탄력적 IP:${NC} $ELASTIC_IP"
    echo -e "${YELLOW}SSH 명령어:${NC} ssh -i $KEY_PATH ubuntu@$ELASTIC_IP"
    echo ""
    echo -e "${CYAN}=== 웹훅 URL 예시 ===${NC}"
    echo -e "${YELLOW}기본 웹훅:${NC} http://$ELASTIC_IP:5678/webhook/your-workflow-name"
    echo ""
    echo -e "${GREEN}✅ 브라우저에서 위 URL로 접속하여 n8n을 사용하세요!${NC}"
    echo -e "${BLUE}📚 n8n 사용법: https://docs.n8n.io${NC}"
    echo ""
    
    # 정보를 파일로 저장
    cat > n8n-info.txt << EOF
n8n 설치 정보
=============

접속 URL: http://$ELASTIC_IP:5678
사용자명: admin
비밀번호: $N8N_PASSWORD

서버 정보:
- 인스턴스 ID: $INSTANCE_ID
- 탄력적 IP: $ELASTIC_IP
- SSH 접속: ssh -i $KEY_PATH ubuntu@$ELASTIC_IP

웹훅 URL 형식:
http://$ELASTIC_IP:5678/webhook/your-workflow-name

설치 일시: $(date)
EOF
    
    echo -e "${CYAN}📄 접속 정보가 'n8n-info.txt' 파일에 저장되었습니다.${NC}"
}

# 메인 실행 함수
main() {
    show_intro
    
    # 필수 도구 확인
    if ! command -v jq &> /dev/null; then
        info_msg "jq 설치 중..."
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt-get update && sudo apt-get install -y jq
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew &> /dev/null; then
                brew install jq
            else
                error_exit "macOS에서는 Homebrew를 먼저 설치해주세요"
            fi
        fi
    fi
    
    check_aws_cli
    get_user_input
    setup_aws_credentials
    get_my_ip
    check_instance
    setup_elastic_ip
    setup_security_group
    test_ssh_connection
    install_n8n
    verify_installation
    show_completion_info
    
    echo -e "${GREEN}🚀 모든 설치가 완료되었습니다! 즐거운 자동화 라이프 되세요! 🚀${NC}"
}

# 스크립트 실행
main "$@"