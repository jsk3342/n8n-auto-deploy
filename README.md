# 🚀 n8n 간편 배포 스크립트

> **5분만에 나만의 n8n 자동화 서버 구축하기 (AWS 프리티어)**

![n8n Logo](https://raw.githubusercontent.com/n8n-io/n8n/master/assets/n8n-logo.png)

## 📋 개요

이 스크립트는 AWS EC2에서 n8n 자동화 플랫폼을 **간편하게** 설치해주는 도구입니다.
복잡한 API 키 설정 없이, AWS 콘솔에서 몇 번의 클릭과 **한 줄 명령어**로 완전한 n8n 환경을 구축할 수 있습니다.

## ✨ 주요 특징

- 🔒 **보안 우선**: SSH 키페어만 사용, API 키 불필요
- 🖱️ **클릭 방식**: AWS 콘솔에서 간단한 클릭 작업
- 🐳 **Docker 기반**: 안정적이고 격리된 환경
- 💰 **프리티어 최적화**: AWS 무료 한도 내에서 운영
- ⚡ **즉시 사용**: 설치 완료 후 바로 워크플로우 생성 가능

## 🎯 설치 과정 (총 소요시간: 약 10분)

### 1단계: AWS 콘솔 작업 (5분)

#### 1-1. EC2 인스턴스 생성

```
1. AWS 콘솔 → EC2 → "인스턴스 시작"
2. AMI: Ubuntu Server 22.04 LTS (프리티어 사용 가능)
3. 인스턴스 타입: t2.micro (프리티어)
4. 키 페어: "새 키 페어 생성" → 이름 입력 → .pem 다운로드
5. 스토리지: 30GB gp2 (프리티어 한도)
6. "인스턴스 시작" 클릭
```

#### 1-2. 탄력적 IP 할당 및 연결

```
1. EC2 → 네트워크 및 보안 → 탄력적 IP
2. "탄력적 IP 주소 할당" 클릭
3. "할당" 클릭
4. 할당된 IP 선택 → 작업 → "탄력적 IP 주소 연결"
5. 인스턴스: 위에서 생성한 인스턴스 선택
6. "연결" 클릭
```

#### 1-3. 보안그룹 포트 추가

```
1. EC2 → 인스턴스 → 생성한 인스턴스 선택
2. 하단 "보안" 탭 → 보안 그룹 클릭
3. "인바운드 규칙" → "인바운드 규칙 편집"
4. "규칙 추가" 클릭:
   • 유형: 사용자 지정 TCP
   • 포트 범위: 5678
   • 소스: 내 IP
5. "규칙 저장" 클릭
```

### 2단계: 자동 설치 (5분)

터미널에서 다음 명령어 한 줄만 실행하세요:

```bash
curl -sSL https://raw.githubusercontent.com/jsk3342/n8n-auto-deploy/main/install.sh | bash
```

### 3단계: 정보 입력

스크립트 실행 시 다음 정보를 입력하세요:

```
탄력적 IP 주소: [1단계에서 할당받은 IP]
키페어(.pem) 파일 경로: [다운로드한 .pem 파일 경로]
n8n 관리자 비밀번호: [8자 이상 비밀번호]
```

## 🎉 완료!

설치가 완료되면 다음과 같은 정보를 받게 됩니다:

```
🎉 n8n 설치가 완료되었습니다! 🎉

=== 접속 정보 ===
n8n URL: http://123.456.789.012:5678
사용자명: admin
비밀번호: [설정한 비밀번호]

=== 웹훅 URL 형식 ===
기본 웹훅: http://123.456.789.012:5678/webhook/워크플로우명
```

## 🌟 n8n 사용 시작하기

### 첫 로그인

1. 브라우저에서 `http://[탄력적-IP]:5678` 접속
2. 사용자명: `admin`, 비밀번호: `[설정한 비밀번호]` 로 로그인

### 첫 번째 워크플로우 만들기

#### 1. 간단한 웹훅 테스트

```
1. "Create your first workflow" 클릭
2. 왼쪽에서 "Manual Trigger" 노드 추가
3. "+" 버튼 → "Set" 노드 추가
4. Set 노드에서 간단한 데이터 설정
5. "Execute Workflow" 버튼으로 테스트
```

#### 2. 실제 웹훅 만들기

```
1. "Webhook" 노드 추가
2. HTTP Method: POST, Path: /test
3. "+" 버튼 → "HTTP Request" 노드 추가
4. URL: https://webhook.site (테스트용)
5. 워크플로우 저장 후 "Active" 토글 켜기
6. Production URL로 테스트:
   curl -X POST http://[IP]:5678/webhook/test
```

## 🛠️ 서버 관리

### SSH 접속

```bash
ssh -i [키페어경로] ubuntu@[탄력적IP]
```

### n8n 관리 도구 (SSH 접속 후)

```bash
# 관리 메뉴 실행
n8n-manager

# 빠른 명령어들
n8n-status    # 상태 확인
n8n-logs      # 로그 실시간 보기
```

### 수동 Docker 명령어

```bash
# 상태 확인
docker ps

# 로그 확인
docker logs n8n -f

# 재시작
docker restart n8n

# 백업
docker exec n8n n8n export:all --output=/tmp/backup.json
docker cp n8n:/tmp/backup.json ./backup-$(date +%Y%m%d).json
```

## 🎭 실제 활용 예시

### 1. GitHub → Slack 알림

```
[Webhook] → [Set] → [Slack]
새 커밋이 푸시될 때마다 슬랙에 알림
```

### 2. 폼 데이터 → Google Sheets

```
[Webhook] → [Google Sheets] → [Gmail]
웹사이트 문의폼 데이터를 자동으로 스프레드시트에 저장하고 이메일 알림
```

### 3. API 모니터링

```
[Cron] → [HTTP Request] → [If] → [Discord]
매 5분마다 API 상태를 체크하고 장애시 Discord 알림
```

### 4. RSS → SNS 자동 포스팅

```
[Cron] → [RSS Read] → [Filter] → [Twitter API]
블로그 RSS를 확인하고 새 글을 SNS에 자동 공유
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
- **데이터 전송**: 일반적으로 무료 한도 내
- **총 예상**: 약 $11.5/월

## 🔒 보안 설정

### 자동 적용된 보안

- ✅ SSH 키페어 기반 인증 (비밀번호 로그인 금지)
- ✅ UFW 방화벽 활성화
- ✅ n8n Basic Auth 인증
- ✅ 보안그룹 IP 제한 (본인 IP만 허용)

### 추가 보안 권장사항

```bash
# 1. 정기적인 시스템 업데이트
sudo apt update && sudo apt upgrade -y

# 2. n8n 비밀번호 주기적 변경
# n8n 설정 → Users → 비밀번호 변경

# 3. 백업 주기적 실행
# cron 설정으로 자동화 권장

# 4. 접속 IP 변경시 보안그룹 업데이트
# AWS 콘솔에서 새 IP로 변경
```

## 🔧 문제 해결

### 자주 발생하는 문제들

#### 1. SSH 연결 실패

```bash
# 해결방법:
1. 키페어 파일 권한 확인: chmod 400 your-key.pem
2. 인스턴스가 실행 중인지 확인
3. 보안그룹에서 SSH(22번 포트) 허용 확인
4. 탄력적 IP가 제대로 연결되었는지 확인
```

#### 2. n8n 접속 불가

```bash
# 해결방법:
1. 보안그룹에서 5678 포트 허용 확인
2. 방화벽 상태 확인: sudo ufw status
3. n8n 서비스 상태 확인: docker ps
4. 로그 확인: docker logs n8n
```

#### 3. 웹훅이 작동하지 않음

```bash
# 해결방법:
1. 워크플로우가 "Active" 상태인지 확인
2. 웹훅 URL이 올바른지 확인
3. 보안그룹에서 외부 접근 허용 확인
4. n8n 로그에서 오류 메시지 확인
```

#### 4. 메모리 부족

```bash
# 해결방법:
1. 불필요한 워크플로우 비활성화
2. 실행 기록 정리: n8n 설정에서 설정
3. Docker 시스템 정리: docker system prune -f
```

### 로그 확인 방법

```bash
# n8n 로그
docker logs n8n --tail 100 -f

# 시스템 로그
sudo journalctl -u docker -f

# 디스크 사용량 확인
df -h

# 메모리 사용량 확인
free -h
```

## 📚 추가 학습 자료

### n8n 공식 자료

- [n8n 공식 문서](https://docs.n8n.io)
- [n8n 커뮤니티](https://community.n8n.io)
- [n8n GitHub](https://github.com/n8n-io/n8n)

### 워크플로우 예시

- [n8n 워크플로우 템플릿](https://n8n.io/workflows)
- [커뮤니티 공유 워크플로우](https://community.n8n.io/c/workflows/10)

### API 연동 가이드

- [n8n API 문서](https://docs.n8n.io/api)
- [웹훅 가이드](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/)

## 🤝 기여하기

이 프로젝트 개선에 참여하고 싶으시다면:

### 버그 리포트

[GitHub Issues](https://github.com/jsk3342/n8n-auto-deploy/issues)에서 문제를 신고해주세요.

### 기능 제안

새로운 기능이나 개선사항이 있다면 Issue로 제안해주세요.

### 코드 기여

```bash
1. Fork this repository
2. Create feature branch: git checkout -b feature/amazing-feature
3. Commit changes: git commit -m 'Add amazing feature'
4. Push to branch: git push origin feature/amazing-feature
5. Open a Pull Request
```

## 🆘 지원 및 문의

### 커뮤니티 지원

- [GitHub Discussions](https://github.com/jsk3342/n8n-auto-deploy/discussions)
- [n8n 커뮤니티 포럼](https://community.n8n.io)

### 문제 신고

- [GitHub Issues](https://github.com/jsk3342/n8n-auto-deploy/issues)

## 📄 라이센스

이 프로젝트는 MIT 라이센스 하에 있습니다.

```
MIT License

Copyright (c) 2025 jsk3342

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## ⭐ 이 프로젝트가 도움이 되셨다면 GitHub Star를 눌러주세요!

**Made with ❤️ for the automation community**

### 🔄 업데이트 히스토리

- **v2.0.0** (2025-06-28): 클릭 방식으로 변경, 보안 강화
- **v1.0.0** (2025-06-27): 초기 버전 릴리스

### 🌟 특별 감사

- [n8n 팀](https://n8n.io)에게 훌륭한 자동화 플랫폼을 만들어주셔서 감사드립니다
- AWS 프리티어 프로그램으로 누구나 쉽게 클라우드를 경험할 수 있게 해주셔서 감사드립니다
- 오픈소스 커뮤니티의 모든 기여자들에게 감사드립니다
