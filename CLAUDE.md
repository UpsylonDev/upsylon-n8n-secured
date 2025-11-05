# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an n8n workflow automation environment with a companion Express.js API server (n8n-runner) that enables remote script/command execution on external projects from n8n workflows.

**Two-service architecture:**
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
# Backup n8n workflows and data
mkdir backup
docker run --rm -v tests-n8n_n8n_data:/data -v $(pwd)/backup:/backup alpine tar czf /backup/n8n-backup.tar.gz -C /data .

# Restore from backup
docker run --rm -v tests-n8n_n8n_data:/data -v $(pwd)/backup:/backup alpine tar xzf /backup/n8n-backup.tar.gz -C /data
```

## Architecture

### n8n Service (Port 5678)
- Runs the n8n workflow automation platform
- Basic auth is DISABLED (docker-compose.yml:11)
- Data persists in Docker volume `n8n_data`
- Timezone: Europe/Paris
- Depends on n8n-runner service

### n8n-runner Service (Port 3000)
- Express.js API server built from `./n8n-runner` directory
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

### Modifying n8n-runner

1. Edit code in `./n8n-runner/` directory
2. Rebuild and restart: `docker-compose up -d --build n8n-runner`
3. View logs: `docker-compose logs -f n8n-runner`

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
- n8n data is preserved across container restarts via Docker volume
- Both services must run for full functionality (n8n depends on n8n-runner)

## Build Issues Fixed

If you encounter Docker build errors:
1. **"cannot replace directory with file"**: Ensure `.dockerignore` exists in n8n-runner/ and excludes node_modules
2. **Version warning**: Remove `version: '3.8'` from docker-compose.yml (obsolete in newer Docker Compose)
3. **Clean rebuild**: Use `docker-compose build --no-cache n8n-runner` after fixing issues
