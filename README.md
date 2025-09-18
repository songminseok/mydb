# 🐳 Docker Database Environment

MySQL과 MariaDB를 위한 완전한 개발 환경입니다. 한 번에 하나의 데이터베이스만 실행되며, 각각 독립적인 데이터 볼륨을 사용합니다.

## 📦 필요한 파일들

다음 파일들을 모두 같은 디렉토리에 배치하세요:

```
docker-databases/
├── docker-compose.yml          # Docker Compose 설정
├── db-manager.sh              # 관리 스크립트 
├── mysql-config/
│   └── my.cnf                 # MySQL 설정
├── mariadb-config/
│   └── my.cnf                 # MariaDB 설정
├── mysql-init/
│   └── init.sql               # MySQL 초기화 SQL
├── mariadb-init/
│   └── init.sql               # MariaDB 초기화 SQL
└── README.md                  # 이 파일
```

## 🚀 빠른 시작

### 1. 환경 준비
```bash
# 실행 권한 부여
chmod +x db-manager.sh

# 환경 확인
./db-manager.sh check
```

### 2. 데이터베이스 시작
```bash
# MySQL 시작
./db-manager.sh start mysql

# MariaDB로 전환
./db-manager.sh switch mariadb
```

### 3. 데이터베이스 접속
```bash
# 현재 실행 중인 DB에 자동 접속
./db-manager.sh connect auto

# 또는 외부 클라이언트로 접속
mysql -h localhost -P 3306 -u root -p
```

## 📋 주요 명령어

| 명령어 | 설명 |
|--------|------|
| `check` | 환경 및 필수 파일 확인 |
| `start mysql` | MySQL 시작 |
| `start mariadb` | MariaDB 시작 |  
| `switch mariadb` | MariaDB로 전환 (MySQL 자동 중지) |
| `connect auto` | 현재 실행 중인 DB에 접속 |
| `status` | 실행 상태 확인 |
| `backup auto` | 현재 DB 백업 |
| `backup-remote <host> <user> [all|db1,db2] [port] [--gzip]` | 원격 DB 백업 |
| `stop current` | 현재 실행 중인 DB 중지 |
| `volumes` | 데이터 볼륨 정보 확인 |
| `clean` | 모든 컨테이너 및 볼륨 삭제 |

## 👤 기본 계정 정보

### Root 계정
- **MySQL**: `root` / `mysql_root_password`
- **MariaDB**: `root` / `mariadb_root_password`

### 개발자 계정
- **사용자**: `developer` / `dev_password`
- **권한**: `development`, `testing` 데이터베이스 모든 권한

### 미리 생성된 데이터베이스
- `development` (개발용)
- `testing` (테스트용)

## 🔌 접속 정보

- **데이터베이스**: `localhost:3306` (MySQL/MariaDB 상호 배타적)
- **phpMyAdmin**: `http://localhost:8080`

## 🗂️ 데이터 관리

### 백업
```bash
# 현재 실행 중인 DB 백업
./db-manager.sh backup auto

# 특정 DB 백업 (실행 중이어야 함)
./db-manager.sh backup mysql

# 원격 DB 백업 (로컬에 mysqldump 없으면 자동으로 Docker 이미지 사용)
# 모든 데이터베이스
./db-manager.sh backup-remote my.remote.host root all

# 특정 데이터베이스들 (콤마 구분)
./db-manager.sh backup-remote my.remote.host root "db1,db2" 3306

# gzip 압축 출력
./db-manager.sh backup-remote 10.0.0.5 admin all 3307 --gzip
```

### 복원
```bash
# 백업 파일 목록 확인
./db-manager.sh restore mysql

# 특정 파일로 복원
./db-manager.sh restore mysql mysql_backup_20250912_143022.sql
```

### 데이터 마이그레이션
```bash
# MySQL → MariaDB 데이터 이동
./db-manager.sh migrate mysql mariadb

# MariaDB → MySQL 데이터 이동
./db-manager.sh migrate mariadb mysql
```

## ⚠️ 중요 사항

### 상호 배타적 실행
- **한 번에 하나의 DB만 실행됩니다** (포트 3306 공유)
- 새 DB 시작 시 기존 DB는 자동으로 중지됩니다
- 리소스 효율성과 포트 충돌 방지

### 독립적인 데이터 볼륨
- **MySQL**: `mysql_data_volume`
- **MariaDB**: `mariadb_data_volume`
- **각 DB의 데이터는 완전히 분리**되어 안전합니다

### 보안 주의사항
- 실제 사용 시 **비밀번호를 변경**하세요
- 외부 접속이 필요한 경우에만 포트를 노출하세요

## 🛠️ 고급 사용법

### 설정 파일 커스터마이징
```bash
# MySQL 설정 수정
nano mysql-config/my.cnf

# MariaDB 설정 수정  
nano mariadb-config/my.cnf

# 변경 후 재시작 필요
./db-manager.sh restart mysql
```

### 초기화 스크립트 추가
```bash
# MySQL 전용 초기화 스크립트
echo "CREATE DATABASE myproject;" >> mysql-init/custom.sql

# MariaDB 전용 초기화 스크립트  
echo "CREATE DATABASE myproject;" >> mariadb-init/custom.sql
```

### 로그 확인
```bash
# 현재 실행 중인 DB 로그
./db-manager.sh logs

# 특정 DB 로그
./db-manager.sh logs mysql
./db-manager.sh logs mariadb
```

## 🔧 문제 해결

### 환경 확인
```bash
# 필수 파일 및 Docker 환경 확인
./db-manager.sh check
```

### 포트 충돌 해결
```bash
# 현재 포트 3306 사용 프로세스 확인
lsof -i :3306

# 모든 DB 컨테이너 중지
./db-manager.sh stop current
```

### 완전 초기화
```bash
# 모든 컨테이너 및 볼륨 삭제 (데이터 손실 주의!)
./db-manager.sh clean

# 새로 시작
./db-manager.sh start mysql
```

## 📞 도움말

```bash
# 전체 명령어 도움말
./db-manager.sh help

# 현재 상태 확인
./db-manager.sh status
```