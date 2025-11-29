# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an n8n workflow automation environment with a companion Express.js API server (n8n-runner) that enables remote script/command execution on external projects from n8n workflows.

**Three-service architecture:**
- **PostgreSQL (Docker)**: Database backend for n8n data persistence (port 5432, internal only)
- **n8n (Docker)**: Workflow automation platform running at http://localhost:5678
- **n8n-runner (Docker)**: Express API server at http://localhost:3000 that executes commands on remote projects

## Essential Commands

### Starting/Stopping the Stack

```bash
# Start both services (n8n + n8n-runner)
docker-compose up -d

# Stop both services
docker-compose down

# View logs
docker-compose logs -f

# View logs for specific service
docker-compose logs -f n8n
docker-compose logs -f n8n-runner

# Restart services
docker-compose restart
```

### Maintenance

```bash
# Update n8n to latest version
docker-compose pull
docker-compose up -d

# Check running containers
docker ps

# Stop and remove all data (WARNING: deletes workflows)
docker-compose down -v
```

### Data Backup

```bash
# Backup PostgreSQL database (recommended method)
docker-compose exec postgres pg_dump -U n8n n8n > backup/n8n-db-backup.sql

# Restore PostgreSQL database
cat backup/n8n-db-backup.sql | docker-compose exec -T postgres psql -U n8n n8n

# Alternative: Backup entire PostgreSQL volume
docker run --rm -v n8n-secure_postgres_data:/data -v $(pwd)/backup:/backup alpine tar czf /backup/postgres-backup.tar.gz -C /data .

# Restore PostgreSQL volume
docker run --rm -v n8n-secure_postgres_data:/data -v $(pwd)/backup:/backup alpine tar xzf /backup/postgres-backup.tar.gz -C /data
```

## Architecture

### PostgreSQL Service (Port 5432, internal only)
- Stores all n8n workflows, credentials, and execution history
- Image: `postgres:15-alpine`
- Database name: `n8n` (configurable via `.env`)
- User: `n8n` (configurable via `.env`)
- Data persists in Docker volume `postgres_data`
- **Transport-friendly**: Volume can be backed up and restored on any machine
- Healthcheck ensures database is ready before n8n starts

### n8n Service (Port 5678)
- Runs the n8n workflow automation platform
- Basic auth configured via `.env` file
- Uses PostgreSQL for all data storage (workflows, credentials, executions)
- Volume `n8n_data` only stores local files (certificates, custom nodes, etc.)
- Timezone: Europe/Paris
- Depends on PostgreSQL (waits for health check) and n8n-runner service

### n8n-runner Service (Port 3000)
- Express.js API server available as Docker image: `upiik/n8n-runner:latest`
- Source code available in `./n8n-runner` directory
- Provides HTTP endpoints for executing scripts/commands on remote projects
- **No authentication** - localhost only, never expose publicly
- Maximum buffer: 10MB for command output

### n8n-runner API Endpoints

**POST /run-script**
- Executes npm/pnpm scripts on a target project
- Request body: `{ "script": "dev", "path": "C:/path/to/project" }`
- The `path` parameter is REQUIRED
- Examples: "dev", "build", "test", "lint"
- Returns: `{ success: boolean, output: string, error: string, exitCode: number }`

**POST /run-command**
- Executes arbitrary bash commands
- Request body: `{ "command": "git status" }`
- Hardcoded to execute in: `C:/dev/experiments/DDD-NUXT/nuxt-domain-driven-design-demo`
- Use with caution - no command validation

**GET /status**
- Health check endpoint
- Returns: `{ status: "running", project: string, timestamp: string }`

### Implementation Details

**n8n-runner.js key points:**
- Uses Node.js `child_process.exec()` for command execution
- Streams stdout/stderr in real-time to console (n8n-runner.js:31-39)
- Non-zero exit codes return HTTP 500 errors
- `/run-script` requires `path` parameter; returns 400 if missing (n8n-runner.js:13-18)
- `/run-command` uses hardcoded path (n8n-runner.js:62)

## Security Warnings

**CRITICAL**: The n8n-runner API has no authentication and executes arbitrary commands:
- Only run on localhost/trusted networks
- Never expose to public internet
- Intended for local development automation only
- Consider adding authentication if deploying beyond localhost

## Integration Pattern

This setup enables powerful local automation workflows:

1. Create workflow in n8n UI (http://localhost:5678)
2. Add HTTP Request node pointing to http://n8n-runner:3000 (or http://localhost:3000)
3. Configure endpoint (/run-script or /run-command) with appropriate payload
4. n8n-runner executes command on target project
5. Results flow back to n8n for further processing

**Common use cases:**
- Automated testing triggered by git webhooks or schedules
- Build automation for multiple projects
- Remote project management from n8n visual interface
- Local CI/CD-like pipelines
- Development task automation (start dev servers, run migrations, etc.)

## Development Workflow

### Using the Pre-built Image (Recommended)

The `docker-compose.yml` uses the pre-built image `upiik/n8n-runner:latest` from Docker Hub. Simply run:
```bash
docker-compose up -d
```

### Modifying n8n-runner

If you need to customize the n8n-runner:

1. Edit code in `./n8n-runner/` directory
2. Update `docker-compose.yml` to use local build:
   ```yaml
   n8n-runner:
     build: ./n8n-runner  # Instead of image: upiik/n8n-runner:latest
   ```
3. Rebuild and restart: `docker-compose up -d --build n8n-runner`
4. View logs: `docker-compose logs -f n8n-runner`

### Publishing Updates to Docker Hub

If you modified the n8n-runner and want to publish your changes:

```bash
# Build the image
docker-compose build n8n-runner

# Tag with your Docker Hub username
docker tag n8n-secure-n8n-runner:latest YOUR_USERNAME/n8n-runner:latest

# Login to Docker Hub
docker login

# Push to Docker Hub
docker push YOUR_USERNAME/n8n-runner:latest

# Update docker-compose.yml to use your image
# Change: image: upiik/n8n-runner:latest
# To:     image: YOUR_USERNAME/n8n-runner:latest
```

### Testing API Endpoints

```bash
# Test status endpoint
curl http://localhost:3000/status

# Run script (requires valid project path)
curl -X POST http://localhost:3000/run-script \
  -H "Content-Type: application/json" \
  -d '{"script":"build","path":"C:/your/project/path"}'

# Run command (uses hardcoded path)
curl -X POST http://localhost:3000/run-command \
  -H "Content-Type: application/json" \
  -d '{"command":"git status"}'
```

## Project Structure

```
.
├── docker-compose.yml       # Orchestrates n8n + n8n-runner services
├── n8n_data/               # Volume mount for n8n persistent data
├── n8n-runner/             # Express API server source code
│   ├── Dockerfile          # Node.js 18 Alpine image
│   ├── .dockerignore       # Excludes node_modules from Docker build
│   ├── n8n-runner.js       # Main Express server implementation
│   ├── package.json        # Dependencies: express, nodemon
│   └── CLAUDE.md           # Detailed n8n-runner documentation
└── README.md               # Comprehensive n8n setup guide (French)

## Important Notes

- The README.md contains extensive French documentation about n8n capabilities, AI integrations, and learning resources
- Current implementation targets a specific Nuxt project path in `/run-command` - modify n8n-runner.js:62 to change this
- The `/run-script` endpoint now requires dynamic path parameter, making it more flexible
- **All workflow data is stored in PostgreSQL**, making it easy to backup and transport between machines
- All three services must run for full functionality (n8n depends on PostgreSQL and n8n-runner)
- PostgreSQL credentials are configured in `.env` file for security

## Database Configuration

### Environment Variables

All database settings are configured via the `.env` file:

```env
# PostgreSQL Configuration
POSTGRES_USER=n8n                      # Database username
POSTGRES_PASSWORD=n8n_secure_password_123  # Database password (CHANGE THIS!)
POSTGRES_DB=n8n                        # Database name
```

**IMPORTANT**: Change the default password in `.env` before deploying!

### Why PostgreSQL?

✅ **Advantages over SQLite (default)**:
- **Portability**: Entire database can be exported as SQL file
- **Backup/Restore**: Simple `pg_dump` command
- **Performance**: Better with large workflows and many executions
- **Transport-friendly**: Move your workflows between machines easily
- **Professional**: Production-ready database system

### Migrating from SQLite to PostgreSQL

If you had workflows in SQLite before adding PostgreSQL:

1. Your old workflows are still in the `n8n_data` volume
2. n8n will start fresh with PostgreSQL (empty database)
3. You need to manually recreate workflows or use n8n's export/import feature

**Migration steps**:
1. Export workflows from old n8n: Settings → Export workflows
2. Stop the stack: `docker-compose down`
3. Start with PostgreSQL: `docker-compose up -d`
4. Import workflows: Settings → Import workflows

## Docker Hub Deployment

### Available Image
- **Docker Hub**: `upiik/n8n-runner:latest`
- **Public**: Anyone can pull and use this image
- **Size**: ~200MB (Node.js 18 Alpine based)

### Quick Start (No Build Required)
Since the image is on Docker Hub, you can deploy the entire stack without building:
```bash
git clone <this-repo>
cd n8n-secure
docker-compose up -d
```

The `n8n-runner` image will be automatically pulled from Docker Hub.

## Build Issues Fixed

If you encounter Docker build errors when building locally:
1. **"cannot replace directory with file"**: Ensure `.dockerignore` exists in n8n-runner/ and excludes node_modules
2. **Version warning**: Remove `version: '3.8'` from docker-compose.yml (obsolete in newer Docker Compose)
3. **Clean rebuild**: Use `docker-compose build --no-cache n8n-runner` after fixing issues
4. **Tag error when pushing**: Always tag before pushing: `docker tag <local-image> <username>/<image>:<tag>`
