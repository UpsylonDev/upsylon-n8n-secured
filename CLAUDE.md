# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an n8n workflow automation server with an Express.js API server (n8n-runner) that enables remote script execution from n8n workflows.

**Architecture:**
- **n8n**: Runs in Docker container (port 5678), provides workflow automation interface
- **n8n-runner.js**: Express API server (port 3000) that executes scripts/commands on a remote project
- **Target project**: Hardcoded path to `C:/dev/experiments/DDD-NUXT/nuxt-domain-driven-design-demo`

## Commands

### n8n Docker Management
```bash
# Start n8n
docker-compose up -d

# Stop n8n
docker-compose down

# View logs
docker-compose logs -f

# Update n8n to latest version
docker-compose pull
docker-compose up -d
```

### n8n-runner API Server
```bash
# Start the API server
npm start

# Start with auto-reload (development)
npm run dev
```

### API Endpoints

The n8n-runner server exposes three endpoints:

**POST /run-script**
- Executes npm/pnpm scripts on the target project
- Body: `{ "script": "dev" }` (e.g., "dev", "build", "test")
- Example: `curl -X POST http://localhost:3000/run-script -H "Content-Type: application/json" -d '{"script":"dev"}'`

**POST /run-command**
- Executes arbitrary bash commands on the target project
- Body: `{ "command": "ls -la" }`
- Example: `curl -X POST http://localhost:3000/run-command -H "Content-Type: application/json" -d '{"command":"git status"}'`

**GET /status**
- Health check endpoint
- Returns server status and project path

## Architecture Notes

### n8n-runner.js Structure

The API server is a simple Express app that:
1. Receives HTTP requests with script/command payloads
2. Uses Node's `child_process.exec()` to execute commands in the target project directory
3. Streams stdout/stderr output back to the caller
4. Returns structured JSON responses with success status, output, and error information

**Key implementation details:**
- All commands execute in the hardcoded `projectPath` directory (n8n-runner.js:11, n8n-runner.js:54)
- 10MB buffer for command output (n8n-runner.js:17)
- Real-time output streaming to console
- Non-zero exit codes return HTTP 500 errors

### Security Considerations

**WARNING**: This API server has no authentication and executes arbitrary commands. It should:
- Only run on localhost/trusted networks
- Never be exposed to the public internet
- Be used only for local development automation

### n8n Configuration

- Basic authentication is **disabled** (docker-compose.yml:9)
- Data persists in Docker volume `n8n_data`
- Accessible at `http://localhost:5678`

## Integration Pattern

This setup enables n8n workflows to trigger actions on local development projects:
1. n8n workflow makes HTTP request to n8n-runner (port 3000)
2. n8n-runner executes the command on the target project
3. Results flow back to n8n for further processing/notifications

Common use cases:
- Automated testing triggered by git webhooks
- Scheduled builds
- Remote project management from n8n UI
- CI/CD-like automation for local development
