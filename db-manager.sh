#!/bin/bash

# Compose 프로젝트 이름 고정
COMPOSE_PROJECT="mydb"

# docker-compose 래퍼 (항상 -p mydb 사용)
dc() {
    docker-compose -p "$COMPOSE_PROJECT" "$@"
}

# 공용 헬퍼 함수들
cd_to_root() {
    cd "$DB_DIR" || exit 1
}

is_valid_service() {
    case "$1" in
        mysql|mariadb) return 0 ;;
        *) return 1 ;;
    esac
}

resolve_service_from_arg() {
    local arg="$1"
    case "$arg" in
        mysql|mariadb)
            echo "$arg"
            ;;
        auto|current|"")
            local running_db=$(get_running_db)
            echo "$running_db"
            ;;
        *)
            echo "invalid"
            ;;
    esac
}

is_up() {
    cd_to_root
    dc ps "$1" | grep -q "Up"
}

service_display_name() {
    case "$1" in
        mysql) echo "MySQL" ;;
        mariadb) echo "MariaDB" ;;
        *) echo "$1" ;;
    esac
}

# 백업 (향상된 버전)
backup_db() {
    cd_to_root
    BACKUP_DIR="$DB_DIR/backups"
    DATE=$(date +%Y%m%d_%H%M%S)

    local service="$(resolve_service_from_arg "$1")"
    if [ "$service" = "invalid" ]; then
        echo -e "${RED}❌ 데이터베이스를 선택하세요. (mysql, mariadb, auto)${NC}"
        return 1
    fi
    if [ "$service" = "none" ]; then
        echo -e "${RED}❌ 실행 중인 데이터베이스가 없습니다.${NC}"
        return 1
    fi

    if ! is_up "$service"; then
        echo -e "${RED}❌ $(service_display_name "$service")이(가) 실행되지 않았습니다. 먼저 시작하세요.${NC}"
        return 1
    fi

    echo -e "${YELLOW}💾 $(service_display_name "$service") 백업 중...${NC}"
    mkdir -p "$BACKUP_DIR"
    dc exec -T "$service" mysqldump -u root -p --all-databases > "$BACKUP_DIR/${service}_backup_$DATE.sql"
    local rc=$?
    if [ $rc -eq 0 ]; then
        echo -e "${GREEN}✅ 백업 완료: $BACKUP_DIR/${service}_backup_$DATE.sql${NC}"
    else
        echo -e "${RED}❌ 백업 실패 (exit $rc)${NC}"
    fi
    return $rc
}

# 복원 기능 (새로 추가)
restore_db() {
    local db_type="$1"
    local backup_file="$2"

    cd_to_root
    BACKUP_DIR="$DB_DIR/backups"

    if [ -z "$backup_file" ]; then
        echo -e "${BLUE}📋 사용 가능한 백업 파일:${NC}"
        ls -la "$BACKUP_DIR"/*.sql 2>/dev/null || echo "백업 파일이 없습니다."
        return 1
    fi

    if [[ "$backup_file" != /* ]]; then
        backup_file="$BACKUP_DIR/$backup_file"
    fi
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}❌ 백업 파일을 찾을 수 없습니다: $backup_file${NC}"
        return 1
    fi

    if ! is_valid_service "$db_type"; then
        echo -e "${RED}❌ 데이터베이스를 선택하세요. (mysql, mariadb)${NC}"
        return 1
    fi

    if ! is_up "$db_type"; then
        echo -e "${YELLOW}⚠️ $(service_display_name "$db_type")가 실행되지 않았습니다. 시작합니다...${NC}"
        start_db "$db_type"
        sleep 3
    fi
    echo -e "${YELLOW}🔄 $(service_display_name "$db_type")로 데이터 복원 중...${NC}"
    dc exec -T "$db_type" mysql -u root -p < "$backup_file"
    local rc=$?
    if [ $rc -eq 0 ]; then
        echo -e "${GREEN}✅ 복원이 완료되었습니다!${NC}"
    else
        echo -e "${RED}❌ 복원 실패 (exit $rc)${NC}"
    fi
    return $rc
}

# 데이터베이스 관리 스크립트
# 사용법: ./db-manager.sh [command] [database]

DB_DIR="$HOME/docker-databases"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 도움말 표시
show_help() {
    echo -e "${BLUE}📊 데이터베이스 관리 스크립트${NC}"
    echo ""
    echo "사용법: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  check          - 환경 및 필수 파일 확인"
    echo "  start [db]     - 데이터베이스 시작 (mysql, mariadb)"
    echo "  stop [db]      - 데이터베이스 중지 (mysql, mariadb, current)"
    echo "  restart [db]   - 데이터베이스 재시작"
    echo "  switch [db]    - 다른 데이터베이스로 전환"
    echo "  status         - 실행 상태 확인"
    echo "  connect [db]   - 데이터베이스 접속 (mysql, mariadb, auto)"
    echo "  logs [db]      - 로그 확인"
    echo "  backup [db]    - 데이터 백업 (mysql, mariadb, auto)"
    echo "  restore [db] [file] - 데이터 복원"
    echo "  migrate [src] [dst] - 데이터 마이그레이션 (mysql→mariadb 등)"
    echo "  volumes        - 볼륨 정보 확인"
    echo "  clean          - 모든 컨테이너 및 볼륨 삭제"
    echo "  update         - 이미지 업데이트"
    echo ""
    echo -e "${YELLOW}⚠️ 중요: MySQL과 MariaDB는 완전히 독립된 데이터 볼륨을 사용합니다${NC}"
    echo ""
    echo "Examples:"
    echo "  $0 check                    # 환경 확인"
    echo "  $0 start mysql              # MySQL 시작 (독립 볼륨)"
    echo "  $0 switch mariadb           # MariaDB로 전환 (독립 볼륨)"
    echo "  $0 backup auto              # 현재 실행중인 DB 백업"
    echo "  $0 migrate mysql mariadb    # MySQL → MariaDB 데이터 이동"
}

# 초기 확인 (setup 대체)
check_environment() {
    echo -e "${BLUE}🔍 환경 확인 중...${NC}"
    
    # 필수 파일들 확인
    local required_files=(
        "docker-compose.yml"
        "mysql-config/my.cnf" 
        "mariadb-config/my.cnf"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    # 필수 디렉토리 확인 및 생성
    local required_dirs=("backups")
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo "✅ 디렉토리 생성: $dir/"
        fi
    done
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ 모든 필수 파일이 준비되어 있습니다!${NC}"
        
        # Docker 확인
        if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
            echo -e "${GREEN}✅ Docker 환경 준비 완료${NC}"
            echo -e "${BLUE}🚀 사용 시작:${NC}"
            echo "  ./db-manager.sh start mysql     # MySQL 시작"
            echo "  ./db-manager.sh start mariadb   # MariaDB 시작"
        else
            echo -e "${YELLOW}⚠️ Docker 또는 Docker Compose가 설치되지 않았습니다${NC}"
        fi
    else
        echo -e "${RED}❌ 누락된 필수 파일들:${NC}"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        echo -e "\n${BLUE}💡 해결 방법:${NC}"
        echo "필요한 파일들을 모두 다운로드하고 올바른 위치에 배치하세요."
        return 1
    fi
}

# 현재 실행 중인 DB 확인
get_running_db() {
    cd "$DB_DIR" || exit 1
    
    if dc ps mysql | grep -q "Up"; then
        echo "mysql"
    elif dc ps mariadb | grep -q "Up"; then
        echo "mariadb"
    else
        echo "none"
    fi
}

# 다른 DB 중지
stop_other_db() {
    local target_db="$1"
    local running_db=$(get_running_db)
    
    if [ "$running_db" != "none" ] && [ "$running_db" != "$target_db" ]; then
        echo -e "${YELLOW}⚠️ ${running_db}가 실행 중입니다. 먼저 중지합니다...${NC}"
        dc stop "$running_db"
        sleep 2
        echo -e "${GREEN}✅ ${running_db} 중지 완료${NC}"
    fi
}

# 데이터베이스 시작 (공통화 버전)
start_db() {
    cd_to_root
    local service="$1"
    if [ -z "$service" ] || ! is_valid_service "$service"; then
        echo -e "${RED}❌ 잘못된 데이터베이스 이름입니다. (mysql, mariadb)${NC}"
        echo -e "${BLUE}💡 현재 실행 중인 DB: $(get_running_db)${NC}"
        return 1
    fi

    stop_other_db "$service"
    echo -e "${GREEN}🚀 $(service_display_name "$service")을(를) 시작합니다...${NC}"
    dc up -d "$service"
    create_db_state_file "$service"

    echo -e "${BLUE}⏳ 데이터베이스 시작을 기다리는 중...${NC}"
    sleep 5

    if is_up "$service"; then
        echo -e "${GREEN}✅ ${service}이(가) 성공적으로 시작되었습니다!${NC}"
        show_connection_info "$service"
    else
        echo -e "${RED}❌ ${service} 시작에 실패했습니다. 로그를 확인하세요:${NC}"
        echo "docker-compose -p $COMPOSE_PROJECT logs ${service}"
        return 1
    fi
}

# 연결 정보 표시
show_connection_info() {
    local db_type="$1"
    echo ""
    echo -e "${BLUE}🔗 연결 정보:${NC}"
    echo "  Host: localhost"
    echo "  Port: 3306"
    echo "  User: root (또는 developer)"
    echo ""
    echo -e "${BLUE}📝 연결 명령어:${NC}"
    case $db_type in
        "mysql")
            echo "  CLI: ./db-manager.sh connect mysql"
            echo "  External: mysql -h localhost -P 3306 -u root -p"
            ;;
        "mariadb")
            echo "  CLI: ./db-manager.sh connect mariadb"  
            echo "  External: mysql -h localhost -P 3306 -u root -p"
            ;;
    esac
    echo "  Web: http://localhost:8080 (phpMyAdmin)"
}

# 상태 파일 생성 (어떤 DB가 실행 중인지 추적)
create_db_state_file() {
    echo "$1" > "$DB_DIR/.current_db"
}

# 상태 파일 삭제
remove_db_state_file() {
    rm -f "$DB_DIR/.current_db"
}

# 현재 활성 DB 표시 (파일 기반) - 사용하지 않음

# 데이터베이스 중지 (공통화 버전)
stop_db() {
    cd_to_root
    local arg="$1"
    local service
    case "$arg" in
        mysql|mariadb) service="$arg" ;;
        all|current|"") service="$(get_running_db)" ;;
        *) echo -e "${RED}❌ 잘못된 데이터베이스 이름입니다. (mysql, mariadb, current)${NC}"; return 1 ;;
    esac

    if [ "$service" = "none" ] || [ -z "$service" ]; then
        echo -e "${BLUE}ℹ️ 실행 중인 데이터베이스가 없습니다.${NC}"
        return 0
    fi

    echo -e "${YELLOW}⏹️ $(service_display_name "$service")를 중지합니다...${NC}"
    docker-compose stop "$service"
    remove_db_state_file
    echo -e "${GREEN}✅ 데이터베이스가 중지되었습니다.${NC}"
}

# 상태 확인 (향상된 버전)
check_status() {
    cd "$DB_DIR" || exit 1
    local running_db=$(get_running_db)
    
    echo -e "${BLUE}📊 데이터베이스 상태:${NC}"
    echo ""
    
    if [ "$running_db" = "none" ]; then
        echo -e "  ${YELLOW}⚪ 실행 중인 데이터베이스 없음${NC}"
        echo ""
        echo -e "${BLUE}💡 사용 가능한 명령:${NC}"
        echo "  ./db-manager.sh start mysql     # MySQL 시작"
        echo "  ./db-manager.sh start mariadb   # MariaDB 시작"
    else
        case $running_db in
            "mysql")
                echo -e "  ${GREEN}🟢 MySQL 실행 중${NC} (포트 3306)"
                ;;
            "mariadb") 
                echo -e "  ${GREEN}🟢 MariaDB 실행 중${NC} (포트 3306)"
                ;;
        esac
        
        echo ""
        echo -e "${BLUE}🔗 연결 방법:${NC}"
        echo "  ./db-manager.sh connect $running_db"
        echo "  mysql -h localhost -P 3306 -u root -p"
        echo "  http://localhost:8080 (phpMyAdmin)"
        
        echo ""
        echo -e "${BLUE}💡 다른 DB로 전환:${NC}"
        if [ "$running_db" = "mysql" ]; then
            echo "  ./db-manager.sh start mariadb   # MariaDB로 전환"
        else
            echo "  ./db-manager.sh start mysql     # MySQL로 전환"
        fi
    fi
    
    echo ""
    echo -e "${BLUE}🐳 Docker 컨테이너 상세 정보:${NC}"
    dc ps
    
    # 포트 사용 현황
    echo ""
    echo -e "${BLUE}🔌 포트 3306 사용 현황:${NC}"
    if lsof -i :3306 2>/dev/null | grep -q LISTEN; then
        lsof -i :3306 | head -2
    else
        echo "  포트 3306 사용 중인 프로세스 없음"
    fi
}

# 데이터베이스 접속 (공통화 버전)
connect_db() {
    local service="$(resolve_service_from_arg "$1")"
    if [ "$service" = "invalid" ]; then
        echo -e "${RED}❌ 데이터베이스를 선택하세요. (mysql, mariadb, auto)${NC}"
        return 1
    fi
    if [ "$service" = "none" ] || ! is_up "$service"; then
        echo -e "${RED}❌ $(service_display_name "$service")이(가) 실행되지 않았습니다.${NC}"
        echo "먼저 시작하세요: ./db-manager.sh start mysql | mariadb"
        return 1
    fi
    echo -e "${GREEN}🔗 $(service_display_name "$service")에 접속합니다...${NC}"
    dc exec -it "$service" mysql -u root -p
}

# 데이터베이스 전환 (새로운 기능)
switch_db() {
    local target_db="$1"
    local current_db=$(get_running_db)
    
    if [ "$current_db" = "$target_db" ]; then
        echo -e "${BLUE}ℹ️ ${target_db}가 이미 실행 중입니다.${NC}"
        show_connection_info "$target_db"
        return 0
    fi
    
    echo -e "${YELLOW}🔄 ${target_db}로 전환합니다...${NC}"
    start_db "$target_db"
}

# 볼륨 정보 확인
check_volumes() {
    echo -e "${BLUE}💾 데이터 볼륨 정보:${NC}"
    echo "MySQL 데이터: mysql_data_volume"
    echo "MariaDB 데이터: mariadb_data_volume"
    echo ""
    
    # 볼륨 실제 위치 확인
    if docker volume ls | grep -q "mysql_data_volume"; then
        mysql_path=$(docker volume inspect mysql_data_volume --format '{{.Mountpoint}}' 2>/dev/null || echo "N/A")
        echo "MySQL 볼륨 경로: $mysql_path"
    else
        echo "MySQL 볼륨: 미생성"
    fi
    
    if docker volume ls | grep -q "mariadb_data_volume"; then
        mariadb_path=$(docker volume inspect mariadb_data_volume --format '{{.Mountpoint}}' 2>/dev/null || echo "N/A")
        echo "MariaDB 볼륨 경로: $mariadb_path"
    else
        echo "MariaDB 볼륨: 미생성"
    fi
}

# 데이터 마이그레이션 도구
migrate_data() {
    local source_db="$1"
    local target_db="$2"
    
    if [ -z "$source_db" ] || [ -z "$target_db" ]; then
        echo -e "${RED}❌ 사용법: migrate_data [source] [target]${NC}"
        echo "예시: migrate_data mysql mariadb"
        return 1
    fi
    
    echo -e "${YELLOW}🔄 $source_db에서 $target_db로 데이터 마이그레이션을 시작합니다...${NC}"
    
    # 백업 생성
    echo "1. $source_db 데이터 백업 중..."
    backup_db "$source_db"
    
    # 대상 DB 시작
    echo "2. $target_db 시작..."
    start_db "$target_db"
    
    # 복원 안내
    echo -e "${GREEN}✅ 마이그레이션 준비 완료!${NC}"
    echo -e "${BLUE}💡 다음 단계:${NC}"
    echo "1. 백업 파일을 확인하세요: ls $DB_DIR/backups/"
    echo "2. 복원하세요: ./db-manager.sh restore $target_db [backup_file]"
}

# 로그 확인
show_logs() {
    cd "$DB_DIR" || exit 1
    
    case $1 in
        "mysql")
            dc logs -f mysql
            ;;
        "mariadb")
            dc logs -f mariadb
            ;;
        *)
            dc logs -f
            ;;
    esac
}

# 메인 로직
case $1 in
    "check")
        check_environment
        ;;
    "start")
        start_db $2
        ;;
    "stop")
        stop_db $2
        ;;
    "restart")
        stop_db $2
        sleep 2
        start_db $2
        ;;
    "status")
        check_status
        ;;
    "connect")
        connect_db $2
        ;;
    "switch")
        if [ -z "$2" ]; then
            echo -e "${RED}❌ 전환할 데이터베이스를 지정하세요. (mysql, mariadb)${NC}"
            exit 1
        fi
        switch_db $2
        ;;
    "backup")
        backup_db $2
        ;;
    "restore")
        restore_db $2 $3
        ;;
    "migrate")
        migrate_data $2 $3
        ;;
    "volumes")
        check_volumes
        ;;
    "logs")
        show_logs $2
        ;;
    "clean")
        cd "$DB_DIR" || exit 1
        echo -e "${RED}🗑️ 모든 컨테이너와 볼륨을 삭제합니다...${NC}"
        read -p "정말 삭제하시겠습니까? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            dc down -v
            docker system prune -f
        fi
        ;;
    "update")
        cd "$DB_DIR" || exit 1
        echo -e "${BLUE}📦 이미지를 업데이트합니다...${NC}"
        dc pull
        dc up -d
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        echo -e "${RED}❌ 알 수 없는 명령입니다.${NC}"
        show_help
        exit 1
        ;;
esac
