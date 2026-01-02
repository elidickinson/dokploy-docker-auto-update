# Auto-Update Docker Images in Dokploy

Dokploy caches images locally and doesn't pull fresh versions on redeploy. You can fix it so manual redeploys pull updated images by adding `pull_policy: always` to the docker compose file, but this assumes you have ready access to the compose file and it still requires a manual action.

This script in this repo runs as a scheduled update job in dokploy that pulls images for the selected services, checks if they've changed, and redploys automatically when needed.

## Setup

### 1. Generate API Key
Settings → Profile → API/CLI → Generate Token

### 2. Create Scheduled Job
Schedule Jobs → Create and fill in fields, then paste contents of [auto-update.sh](auto-update.sh) or [single-project.sh](single-project.sh) and configure.

### [auto-update.sh](auto-update.sh) (Recommended)

```bash
API_KEY="your-api-key-here"
API_URL="http://localhost:3000/api"
SERVICES="my-compose-abc123 other-compose-def456"  # Space-separated appNames
```

Auto-discovers images from compose files. Errors if appName not found.

Get appName from: Compose → General → App Name (or via `project.all` API)

### [single-project.sh](single-project.sh) (Alternative)

Manual config when you need explicit control over which images to watch.
```bash
API_KEY="your-api-key-here"
COMPOSE_ID="your-compose-id-here"
IMAGES="myregistry/myapp:latest redis:7"
```
Get composeId from URL: `/service/compose/{composeId}` (or via `project.all` API)

### 3. Test First
Use "Run Manually" before relying on the schedule. Check job logs.
