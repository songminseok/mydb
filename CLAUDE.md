# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Docker-based development environment for MySQL and MariaDB databases. The system is designed for **mutually exclusive operation** - only one database runs at a time on port 3306, with completely isolated data volumes for each database.

## Essential Commands

### Database Management (Use db-manager.sh script)
```bash
# Environment setup and checks
./db-manager.sh check                    # Verify environment and required files

# Database operations
./db-manager.sh start mysql              # Start MySQL (stops MariaDB if running)
./db-manager.sh start mariadb            # Start MariaDB (stops MySQL if running)
./db-manager.sh switch mariadb           # Switch to MariaDB (auto-stops current DB)
./db-manager.sh stop current             # Stop currently running database
./db-manager.sh status                   # Check running status and port usage

# Database connection
./db-manager.sh connect auto             # Connect to currently running database
./db-manager.sh connect mysql            # Connect specifically to MySQL (if running)

# Data management
./db-manager.sh backup auto              # Backup current running database
./db-manager.sh restore mysql backup.sql # Restore from backup file
./db-manager.sh migrate mysql mariadb    # Data migration between databases
```

### Direct Docker Compose (Use sparingly)
```bash
# Only when script doesn't cover specific needs
docker-compose -p mydb up -d mysql       # Start MySQL service
docker-compose -p mydb ps                # Check container status
docker-compose -p mydb logs mysql        # View MySQL logs
```

## Architecture & Core Principles

### Mutually Exclusive Database Operation
- **Critical**: Only one database (MySQL or MariaDB) runs at a time
- Both databases share port 3306 on the host
- The db-manager.sh script automatically stops the running database when starting another
- Always use the script for database switching to ensure proper resource management

### Data Isolation
- **MySQL data**: `mysql_data_volume` (completely isolated)
- **MariaDB data**: `mariadb_data_volume` (completely isolated)  
- Each database maintains its own independent dataset
- Data migration requires explicit backup/restore operations

### Service Configuration
- **MySQL**: `mysql:8.0` image, container name `mysql`
- **MariaDB**: `mariadb:10.11` image, container name `mariadb`
- **phpMyAdmin**: Available at `http://localhost:8080` (connects to host.docker.internal:3306)
- **Network**: `database_network` (bridge mode)

## File Structure & Responsibilities

```
/Users/minseok/docker-databases/
├── db-manager.sh              # Primary orchestration script (all operations)
├── docker-compose.yml         # Service definitions (ports, volumes, health checks)
├── mysql-config/my.cnf        # MySQL-specific configuration
├── mariadb-config/my.cnf      # MariaDB-specific configuration
├── mysql-init/               # MySQL initialization SQL scripts (optional)
├── mariadb-init/             # MariaDB initialization SQL scripts (optional)
└── backups/                  # Generated backup files directory
```

### Configuration Details
- **mysql-config/my.cnf**: MySQL 8.0 optimizations, utf8mb4 charset, no query cache (removed in 8.0)
- **mariadb-config/my.cnf**: MariaDB 10.11 optimizations, utf8mb4 charset, query cache enabled
- **Container internal port**: Always 3306 (never change)
- **Host port mapping**: Configurable in docker-compose.yml (default 3306)

## Working with the Cursor Rules

The `.cursorrules` file contains Korean-language development guidelines that emphasize:

1. **Safety First**: Never run MySQL and MariaDB simultaneously
2. **Script Preference**: Always use `./db-manager.sh` commands over direct docker-compose
3. **Port Management**: Only modify external port mapping, keep internal port 3306
4. **Absolute Paths**: Prefer absolute paths `/Users/minseok/docker-databases`
5. **Service Names**: Use exact service names `mysql`, `mariadb`, `phpmyadmin`

## Default Credentials

- **Root password**: `root123$` (both MySQL and MariaDB)
- **Host**: `localhost:3306`
- **phpMyAdmin**: `http://localhost:8080`

## Common Development Patterns

### Port Conflict Resolution
```bash
# Check what's using port 3306
lsof -i :3306

# Stop current database
./db-manager.sh stop current

# Modify docker-compose.yml to use different host port
# Change "3306:3306" to "3307:3306" (external:internal)
```

### Database Switching Workflow
```bash
# Always use switch command (not start) for transitions
./db-manager.sh switch mariadb    # Safely transitions from MySQL to MariaDB
./db-manager.sh status           # Verify the switch
```

### Configuration Changes
```bash
# After modifying *-config/my.cnf files
./db-manager.sh restart mysql    # Apply configuration changes
```

## Quality Checks

After any changes:
```bash
./db-manager.sh check            # Verify environment
./db-manager.sh start mysql      # Test startup
./db-manager.sh status          # Confirm health and port binding
./db-manager.sh logs            # Check for errors if needed
```