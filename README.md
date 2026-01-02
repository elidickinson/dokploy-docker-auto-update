# Auto-Update Docker Images in Dokploy

Dokploy caches images locally and doesn't pull fresh versions on redeploy. This script runs as a scheduled job to pull images, compare digests, and redeploy automatically when a a tagged Docker image is updated.

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
