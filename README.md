# 🚀 n8n 원클릭 배포 시스템

> **5분만에 나만의 n8n 자동화 서버 구축하기 (AWS 프리티어)**

![n8n Logo](https://raw.githubusercontent.com/n8n-io/n8n/master/assets/n8n-logo.png)

## 📋 개요

AWS EC2에서 n8n 자동화 플랫폼을 **원클릭으로** 설치하는 스크립트입니다.
복잡한 설정 없이 **한 줄 명령어**로 완전한 n8n 환경을 구축하고,
실용적인 워크플로우 템플릿을 바로 사용할 수 있습니다.

## ✨ 주요 특징

- 🔒 **보안 우선**: SSH 키페어 기반, 방화벽 자동 설정
- 🌐 **고정 IP**: 탄력적 IP로 언제나 동일한 주소
- 🐳 **Docker 기반**: 안정적이고 격리된 환경
- 💰 **프리티어 최적화**: AWS 무료 한도 내에서 운영
- ⚡ **즉시 사용**: 설치 완료 후 바로 워크플로우 임포트 가능
- 🎯 **실용적 템플릿**: 바로 쓸 수 있는 자동화 예시 제공

## 🎯 설치 과정 (총 10분)

### 1단계: AWS 콘솔 작업 (5분)

#### 1-1. EC2 인스턴스 생성

```
AWS 콘솔 → EC2 → "인스턴스 시작"
• AMI: Ubuntu Server 22.04 LTS (프리티어)
• 인스턴스 타입: t2.micro (프리티어)
• 키 페어: 새로 생성 후 .pem 파일 다운로드
• 스토리지: 30GB gp2 (프리티어)
• "인스턴스 시작" 클릭
```

#### 1-2. 탄력적 IP 할당 및 연결

```
EC2 → 네트워크 및 보안 → 탄력적 IP
• "탄력적 IP 주소 할당" → "할당"
• 생성된 IP 선택 → 작업 → "탄력적 IP 주소 연결"
• 인스턴스: 위에서 생성한 인스턴스 선택 → "연결"
```

#### 1-3. 보안그룹 포트 추가

```
EC2 → 인스턴스 → 생성한 인스턴스 선택
• 하단 "보안" 탭 → 보안 그룹 클릭
• "인바운드 규칙" → "인바운드 규칙 편집"
• "규칙 추가": 사용자 지정 TCP, 포트 5678, 소스: 내 IP
• "규칙 저장"
```

### 2단계: 원클릭 설치 (5분)

#### 방법 A: 로컬 터미널에서 SSH 접속

```bash
curl -sSL https://raw.githubusercontent.com/jsk3342/n8n-auto-deploy/main/install.sh | N8N_PASSWORD=mypass123 bash
```

#### 방법 B: AWS 웹 터미널에서 직접 실행 (추천)

```
1. AWS 콘솔 → EC2 → 인스턴스 선택 → "연결" 버튼
2. "EC2 Instance Connect" 선택 → "연결" 클릭
3. 웹 터미널에서 실행:
```

```bash
curl -sSL https://raw.githubusercontent.com/jsk3342/n8n-auto-deploy/main/server-install.sh | N8N_PASSWORD=mypass123 bash
```

## 🎉 설치 완료!

설치가 완료되면 다음과 같은 정보를 받게 됩니다:

```
🎉 n8n 설치가 완료되었습니다! 🎉

=== 📱 접속 정보 ===
🌐 URL: http://123.456.789.012:5678
👤 사용자명: admin
🔐 비밀번호: mypass123

=== 🔗 워크플로우 템플릿 ===
n8n에서 'Import workflow' → 'From URL'로 다음 링크들을 사용하세요:

1. AI 비서 극존칭 출근 알림
   https://raw.githubusercontent.com/.../ai-secretary-commute.json
```

## 🌟 워크플로우 템플릿 사용법

### 1. n8n 접속 및 로그인

```
브라우저에서 http://[탄력적-IP]:5678 접속
사용자명: admin, 비밀번호: [설정한 비밀번호]
```

### 2. 워크플로우 임포트

```
1. n8n 왼쪽 메뉴에서 "Workflows" 클릭
2. "+" → "Import workflow" 선택
3. "From URL" 탭 선택
4. 위에서 제공된 GitHub Raw URL 붙여넣기
5. "Import" 클릭
```

### 3. 워크플로우 활성화

```
1. 임포트된 워크플로우 열기
2. 우측 상단 "Inactive" → "Active" 토글 켜기
3. 필요시 Credentials(API 키) 설정
```

## 🎭 포함된 워크플로우 템플릿

### 1. 🤖 AI 비서 극존칭 출근 알림

- **기능**: 네이버 지도 + AI + 카카오톡으로 VIP 대우받는 출근 정보
- **스케줄**: 매일 오전 9:30 자동 실행
- **필요 API**: 네이버 클라우드, 카카오톡, OpenAI

### 2. 🔗 간단한 웹훅 테스트

- **기능**: n8n 웹훅의 기본 동작 이해를 위한 테스트
- **사용법**: `POST http://[IP]:5678/webhook/test`
- **필요 API**: 없음 (즉시 사용 가능)

## 🛠️ 서버 관리

### SSH 접속

```bash
ssh -i [키페어경로] ubuntu@[탄력적IP]
```

### n8n 관리 (SSH 접속 후)

```bash
# 관리 메뉴 실행
n8n-manager

# 수동 명령어
cd ~/n8n
sudo docker-compose ps      # 상태 확인
sudo docker-compose logs    # 로그 보기
sudo docker-compose restart # 재시작
```

## 💰 비용 안내

### AWS 프리티어 (12개월 무료)

- **EC2 t2.micro**: 월 750시간 (24시간 × 31일)
- **EBS gp2**: 월 30GB 스토리지
- **데이터 전송**: 월 15GB
- **탄력적 IP**: 실행 중인 인스턴스 연결시 무료

### 프리티어 이후 예상 비용

- **EC2 t2.micro**: 약 $8.5/월 (서울 리전)
- **EBS 30GB**: 약 $3/월
- **총 예상**: 약 $11.5/월

## 🔒 보안 설정

### 자동 적용된 보안

- ✅ SSH 키페어 기반 인증
- ✅ UFW 방화벽 활성화 (SSH, 5678 포트만 허용)
- ✅ n8n Basic Auth 인증
- ✅ 보안그룹 IP 제한

### 추가 보안 권장사항

```bash
# 정기적인 시스템 업데이트
sudo apt update && sudo apt upgrade -y

# 접속 IP 변경시 보안그룹 업데이트
# AWS 콘솔에서 새 IP로 변경

# 정기 백업
n8n-manager → 7) 백업
```

## 🔧 문제 해결

### 자주 발생하는 문제들

#### 1. n8n 접속 불가

```bash
# 해결방법:
1. 보안그룹에서 5678 포트 허용 확인
2. n8n 서비스 상태 확인: n8n-manager → 1) 상태 확인
3. 방화벽 확인: sudo ufw status
```

#### 2. 워크플로우 임포트 실패

```bash
# 해결방법:
1. GitHub Raw URL이 정확한지 확인
2. 인터넷 연결 상태 확인
3. n8n이 최신 버전인지 확인
```

#### 3. 웹훅이 작동하지 않음

```bash
# 해결방법:
1. 워크플로우가 "Active" 상태인지 확인
2. 웹훅 URL이 올바른지 확인: http://[IP]:5678/webhook/[path]
3. 보안그룹에서 외부 접근 허용 확인
```

## 📚 추가 학습 자료

### n8n 공식 자료

- [n8n 공식 문서](https://docs.n8n.io)
- [n8n 커뮤니티](https://community.n8n.io)
- [워크플로우 템플릿](https://n8n.io/workflows)

### API 설정 가이드

각 워크플로우에 필요한 API 키 발급 방법:

#### 네이버 클라우드 플랫폼 (지도 API)

```
1. https://console.ncloud.com 접속
2. Services → AI·Application Service → Maps
3. 애플리케이션 등록 → API 키 발급
4. n8n Credentials에 추가
```

#### 카카오톡 API (메시지 전송)

```
1. https://developers.kakao.com 접속
2. 내 애플리케이션 → 애플리케이션 추가
3. 제품 설정 → 카카오 로그인 활성화
4. OAuth 토큰 발급 후 n8n에 추가
```

#### OpenAI API (AI 기능)

```
1. https://platform.openai.com 접속
2. API Keys → Create new secret key
3. 발급받은 키를 n8n Credentials에 추가
```

## 🤝 기여하기

### 새로운 워크플로우 템플릿 추가

1. `workflows/basic/` 폴더에 JSON 파일 추가
2. README에 설명 추가
3. Pull Request 생성

### 버그 리포트 및 개선 제안

- [GitHub Issues](https://github.com/jsk3342/n8n-auto-deploy/issues)

## 🆘 지원

### 문제 신고

- [GitHub Issues](https://github.com/jsk3342/n8n-auto-deploy/issues)
- [n8n 커뮤니티 포럼](https://community.n8n.io)

### 자주 묻는 질문

**Q: 프리티어로 얼마나 사용할 수 있나요?**
A: 12개월간 월 750시간(24시간×31일) 무료로 사용 가능합니다.

**Q: 워크플로우를 더 추가하고 싶어요.**
A: GitHub에서 새로운 워크플로우 JSON을 찾거나, 직접 만든 후 Export하여 공유할 수 있습니다.

**Q: n8n을 업데이트하려면?**
A: `n8n-manager` → 3) 중지 → `sudo docker-compose pull` → 2) 시작

## 📄 라이센스

MIT License - 자유롭게 사용, 수정, 배포 가능합니다.

---

## ⭐ 이 프로젝트가 도움이 되셨다면 GitHub Star를 눌러주세요!

### 🔄 버전 히스토리

- **v3.0.0** (2025-06-29): URL 기반 워크플로우 임포트, 설치 과정 대폭 단순화
- **v2.0.0** (2025-06-28): 웹 터미널 지원, 보안 강화
- **v1.0.0** (2025-06-27): 초기 버전 릴리스

### 🌟 특별 감사

- [n8n 팀](https://n8n.io) - 훌륭한 자동화 플랫폼
- AWS 프리티어 프로그램 - 누구나 쉽게 클라우드 경험
- 오픈소스 커뮤니티의 모든 기여자들

**Made with ❤️ for the automation community**
