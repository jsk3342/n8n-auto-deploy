# 🚀 n8n 원클릭 배포 스크립트

> **5분만에 나만의 n8n 자동화 서버 구축하기 (AWS 프리티어)**

![n8n Logo](https://raw.githubusercontent.com/n8n-io/n8n/master/assets/n8n-logo.png)

## 📋 개요

이 스크립트는 AWS EC2에서 n8n 자동화 플랫폼을 **완전 자동으로** 설치해주는 도구입니다.
복잡한 서버 설정, Docker 설치, 보안 구성을 **한 번에 처리**하여 바로 사용할 수 있는 n8n 환경을 제공합니다.

## ✨ 주요 기능

- 🔒 **보안 우선**: SSH 키페어 기반 접속, IP 제한 보안그룹
- 🌐 **탄력적 IP**: 고정 IP 자동 할당으로 언제나 동일한 주소
- 🐳 **Docker 기반**: 안정적이고 격리된 환경
- 💰 **프리티어 최적화**: AWS 무료 한도 내에서 운영
- ⚡ **원클릭 배포**: 한 줄 명령어로 모든 설정 완료

## 🎯 사전 준비사항

### 1. AWS 계정 및 EC2 인스턴스

1. **AWS 계정 생성** (무료)

   - [aws.amazon.com](https://aws.amazon.com)에서 계정 생성
   - 신용카드 등록 필요 (프리티어 사용시 요금 없음)

2. **EC2 인스턴스 생성**

   ```
   • AMI: Ubuntu 22.04 LTS (프리티어 사용 가능)
   • 인스턴스 타입: t2.micro (프리티어)
   • 키 페어: 새로 생성 후 .pem 파일 다운로드
   • 스토리지: 30GB gp2 (프리티어 한도)
   ```

3. **AWS Access Key 발급**
   ```
   AWS 콘솔 → IAM → Users → Create User
   → Attach Policy: AdministratorAccess
   → Security Credentials → Create Access Key
   → Command Line Interface 선택
   → Access Key ID + Secret Access Key 복사
   ```

### 2. 로컬 환경

- **운영체제**: Linux, macOS, Windows (WSL)
- **필수 도구**: curl, bash (대부분 기본 설치됨)
- **권장 도구**: AWS CLI (스크립트가 자동 설치)

## 🚀 설치 방법

### 원클릭 설치

```bash
curl -sSL https://raw.githubusercontent.com/jsk3342/n8n-auto-deploy/main/install.sh | bash
```

### 수동 다운로드 후 실행

```bash
# 스크립트 다운로드
wget https://raw.githubusercontent.com/jsk3342/n8n-auto-deploy/main/install.sh

# 실행 권한 부여
chmod +x install.sh

# 실행
./install.sh
```

## 📝 설치 과정

### 1. 정보 입력

스크립트 실행 후 다음 정보들을 입력하세요:

```
EC2 인스턴스 ID: i-1234567890abcdef0
키페어(.pem) 파일 경로: ~/.ssh/my-n8n-key.pem
AWS Access Key ID: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key: [보안상 숨김]
AWS 리전: ap-northeast-2
n8n 관리자 비밀번호: [8자 이상]
```

### 2. 자동 처리 과정

스크립트가 다음 작업들을 자동으로 수행합니다:

1. ✅ AWS CLI 설치 및 설정
2. ✅ 탄력적 IP 할당 및 연결
3. ✅ 보안그룹 생성 (본인 IP만 허용)
4. ✅ SSH 연결 테스트
5. ✅ 서버 업데이트 및 Docker 설치
6. ✅ n8n 설치 및 설정
7. ✅ 방화벽 구성
8. ✅ 서비스 시작 및 확인

### 3. 완료 확인

설치가 완료되면 다음과 같은 정보를 받게 됩니다:

```
🎉 n8n 설치가 완료되었습니다! 🎉

=== 접속 정보 ===
n8n URL: http://123.456.789.012:5678
사용자명: admin
비밀번호: [설정한 비밀번호]

=== 웹훅 URL 예시 ===
기본 웹훅: http://123.456.789.012:5678/webhook/your-workflow-name
```

## 🌟 n8n 사용법

### 첫 번째 워크플로우 만들기

1. **브라우저에서 접속**

   ```
   http://[탄력적-IP]:5678
   ```

2. **로그인**

   ```
   사용자명: admin
   비밀번호: [설정한 비밀번호]
   ```

3. **간단한 웹훅 테스트**
   - Manual Trigger 노드 추가
   - HTTP Request 노드 연결
   - webhook.site에서 테스트 URL 생성
   - 워크플로우 실행해보기

### 실제 활용 예시

```javascript
// GitHub → Slack 알림 워크플로우
[Webhook] → [Set] → [Slack]

// 폼 데이터 → Google Sheets
[Webhook] → [Google Sheets] → [Gmail]

// API 모니터링
[Cron] → [HTTP Request] → [If] → [Discord]
```

## 🔧 관리 명령어

### SSH 접속

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@[탄력적-IP]
```

### n8n 관리

```bash
# 상태 확인
docker ps

# 로그 확인
docker logs n8n -f

# 재시작
docker restart n8n

# 중지
docker stop n8n

# 시작
docker start n8n
```

### 백업

```bash
# n8n 데이터 백업
docker exec n8n n8n export:all --output=/tmp/backup.json
docker cp n8n:/tmp/backup.json ./n8n-backup-$(date +%Y%m%d).json
```

## 💰 비용 안내

### AWS 프리티어 (12개월 무료)

- **EC2 t2.micro**: 월 750시간 (약 31일)
- **EBS gp2**: 월 30GB
- **데이터 전송**: 월 15GB
- **탄력적 IP**: 실행 중인 인스턴스 연결시 무료

### 예상 월 비용 (프리티어 이후)

- **EC2 t2.micro**: 약 $10/월
- **EBS 30GB**: 약 $3/월
- **탄력적 IP**: $0 (연결시)
- **총 예상 비용**: 약 $13/월

## 🛡️ 보안 고려사항

### 적용된 보안 설정

- ✅ SSH 키페어 기반 인증 (비밀번호 로그인 비활성화)
- ✅ 보안그룹: 본인 IP만 허용
- ✅ UFW 방화벽 활성화
- ✅ n8n Basic Auth 인증
- ✅ 최신 보안 업데이트 적용

### 추가 보안 권장사항

```bash
# 정기적인 시스템 업데이트
sudo apt update && sudo apt upgrade -y

# n8n 비밀번호 변경
# n8n 설정에서 수정 가능

# 백업 주기적 실행
# cron으로 자동화 권장
```

## 🔍 문제 해결

### 일반적인 문제들

#### 1. SSH 연결 실패

```bash
# 키페어 권한 확인
chmod 400 ~/.ssh/your-key.pem

# 보안그룹 확인
# AWS 콘솔에서 22번 포트 허용 여부 확인
```

#### 2. n8n 접속 불가

```bash
# 서비스 상태 확인
ssh -i ~/.ssh/your-key.pem ubuntu@[IP]
docker ps
docker logs n8n

# 방화벽 확인
sudo ufw status
```

#### 3. 웹훅 URL 오류

```bash
# 환경변수 확인
docker exec n8n env | grep WEBHOOK
```

### 로그 확인 방법

```bash
# n8n 로그
docker logs n8n --tail 100 -f

# 시스템 로그
sudo journalctl -u docker -f
```

## 🤝 기여하기

이 프로젝트를 개선하고 싶으시다면:

1. Fork this repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 라이센스

이 프로젝트는 MIT 라이센스 하에 있습니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 🆘 지원

### 문제 신고

- [GitHub Issues](https://github.com/jsk3342/n8n-auto-deploy/issues)에서 문제를 신고해주세요.

### 커뮤니티

- [n8n 공식 커뮤니티](https://community.n8n.io/)
- [n8n 공식 문서](https://docs.n8n.io/)

### 연락처

- 이메일: your-email@example.com
- 블로그: [your-blog-url]

---

## ⭐ 이 프로젝트가 도움이 되셨다면 GitHub Star를 눌러주세요!

**Made with ❤️ for the automation community**
