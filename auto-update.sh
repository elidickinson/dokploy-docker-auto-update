#!/bin/bash

set -e

API_KEY="your-api-key-here"
API_URL="http://localhost:3000/api"
SERVICES="my-compose-abc123 other-compose-def456"  # Space-separated compose appNames

# Fetch all projects and extract all compose services
ALL_COMPOSES=$(curl -sf "$API_URL/project.all" -H "x-api-key: $API_KEY" | jq -r '
  [.[] | .environments[]?.compose[]? | {appName, composeId}] | .[]
')

for APP_NAME in $SERVICES; do
  COMPOSE_ID=$(echo "$ALL_COMPOSES" | jq -r --arg name "$APP_NAME" 'select(.appName == $name) | .composeId')

  if [ -z "$COMPOSE_ID" ]; then
    echo "ERROR: Compose service '$APP_NAME' not found" >&2
    exit 1
  fi

  # Get compose file content
  COMPOSE_YAML=$(curl -sf "$API_URL/compose.getConvertedCompose?composeId=$COMPOSE_ID" \
    -H "x-api-key: $API_KEY")

  # Extract images from YAML
  IMAGES=$(echo "$COMPOSE_YAML" | grep -oE 'image:\s*["\x27]?[^"\x27\s]+["\x27]?' |
           sed -E "s/image:\s*['\"]?//g" | sed -E "s/['\"]$//g" | sort -u)

  if [ -z "$IMAGES" ]; then
    echo "[$APP_NAME] No images found, skipping"
    continue
  fi

  CHANGED=0
  for IMAGE in $IMAGES; do
    # Skip if no running container uses this image
    docker ps -q --filter "ancestor=$IMAGE" | grep -q . || continue

    OLD=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE" 2>/dev/null || echo "")
    docker pull -q "$IMAGE"
    NEW=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE" 2>/dev/null || echo "")

    if [ "$OLD" != "$NEW" ]; then
      echo "[$APP_NAME] Updated: $IMAGE"
      CHANGED=1
    fi
  done

  if [ "$CHANGED" -eq 1 ]; then
    echo "[$APP_NAME] Deploying..."
    curl -sf -X POST "$API_URL/compose.redeploy" \
      -H "Content-Type: application/json" \
      -H "x-api-key: $API_KEY" \
      -d "{\"composeId\": \"$COMPOSE_ID\"}"
    echo
  fi
done

echo "Done"
