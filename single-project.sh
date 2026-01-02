#!/bin/bash
#
# API_KEY: Settings → Profile → API/CLI → Generate Token
# COMPOSE_ID: From URL /service/compose/{composeId}
# IMAGES: Space-separated images to watch

set -e

API_KEY="your-api-key-here"
COMPOSE_ID="your-compose-id-here"
IMAGES="myregistry/myapp:latest redis:7"

CHANGED=0

for IMAGE in $IMAGES; do
  # Skip if no running container uses this image
  docker ps -q --filter "ancestor=$IMAGE" | grep -q . || continue

  OLD=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE")
  docker pull -q "$IMAGE"
  NEW=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE")

  if [ "$OLD" != "$NEW" ]; then
    echo "Updated: $IMAGE"
    CHANGED=1
  fi
done

if [ "$CHANGED" -eq 1 ]; then
  echo "Deploying..."
  curl -f -X POST 'http://localhost:3000/api/compose.redeploy' \
    -H 'Content-Type: application/json' \
    -H "x-api-key: $API_KEY" \
    -d "{\"composeId\": \"$COMPOSE_ID\"}" && echo
else
  echo "No changes"
fi
