# Auto-Update Docker Images in Dokploy

Automatically pull fresh images and redeploy when they change—without modifying upstream compose files.

## The Problem

Dokploy doesn't automatically pull new images when you redeploy. If you're using `latest` or other mutable tags, clicking "Deploy" just reuses the cached local image. The usual fix is adding `pull_policy: always` to your compose file, but that's not always possible if you don't control the file.

## The Solution

A Dokploy Server scheduled job that:

1. Checks for running containers using specific images
2. Pulls fresh versions of those images
3. Triggers a redeploy only if something actually changed

This runs entirely inside Dokploy—no external containers or tools needed.

## Setup

### 1. Generate an API Key

Settings → Profile → API/CLI Section → Generate Token

### 2. Create the Scheduled Job

Go to Schedule Jobs → Create:

- **Type**: Dokploy Server
- **Name**: Auto-update myapp (or whatever)
- **Cron**: `0 4 * * *` (daily at 4am, adjust as needed)
- **Command**: See scripts below

### 3. Test First

Use the "Run Manually" button to verify it works before relying on the schedule. Check the job logs for output.

## The Scripts

### auto-update.sh (Recommended)

Specify project names and the script automatically discovers compose services and their images:

```bash
API_KEY="your-api-key-here"
API_URL="http://localhost:3000/api"
PROJECTS="my-project another-project"  # Space-separated project names
```

- Queries the Dokploy API to find compose services in each project
- Parses compose files to extract image names automatically
- Errors if a project name isn't found
- Redeploys only projects with updated images

### single-project.sh

Manual configuration if you need more control:

```bash
API_KEY="your-api-key-here"
COMPOSE_ID="your-compose-id-here"  # Get from URL: /service/compose/{composeId}
IMAGES="myregistry/myapp:latest redis:7"
```

Both scripts include `set -e` for fail-fast and `curl -f` for API error checking.

## How It Works

1. **Dokploy Server jobs** run inside the Dokploy container, which has access to the Docker socket and has `curl` installed

2. **`set -e`** ensures the script fails fast if any command fails (docker pull fails, API call fails, etc.)

3. **`docker ps --filter "ancestor=$IMAGE"`** finds running containers using that image. If none exist, the image is skipped—this prevents deploying services that aren't actually live

4. **`docker inspect ... RepoDigests`** gets the image's digest (content hash), which changes when the upstream image changes even if the tag stays the same

5. **`docker pull`** fetches the latest version. If the digest changed, we flag it

6. **`curl -f`** triggers a redeploy and fails if the API call fails. Because the local image is now newer than what the container is running, Docker recreates the container with the new image

## Notes

- Job logs are visible in Dokploy's Schedule Jobs section
- The running container check means you can list images that might not be deployed yet—they'll just be skipped
- All errors cause the script to exit immediately (fail fast)
- API key is stored in plain text in the job - acceptable for self-hosted instances

## Cron Examples

| Schedule | Cron Expression |
|----------|-----------------|
| Daily at 4am | `0 4 * * *` |
| Every 6 hours | `0 */6 * * *` |
| Weekdays at 3am | `0 3 * * 1-5` |
| Every 15 minutes | `*/15 * * * *` |

## Troubleshooting

**Project not found**: Verify the project name matches exactly (case-sensitive). Check `project.all` API response in Swagger.

**API errors**: Verify your API key is valid. Test curl commands manually via Dokploy's terminal.

**Images not pulling**: Make sure the Dokploy container can reach your registry.

**Script exits early**: With `set -e`, any error stops the script. Check logs for the specific error.
