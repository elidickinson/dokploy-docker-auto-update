#!/bin/bash

set -e

API_KEY="your-api-key-here"
API_URL="http://localhost:3000/api"
PROJECTS="my-project another-project"  # Space-separated project names

# Fetch all projects
ALL_PROJECTS=$(curl -sf "$API_URL/project.all" -H "x-api-key: $API_KEY")

for PROJECT_NAME in $PROJECTS; do
  # Find project and extract compose services
  # Projects have environments, environments have compose services
  COMPOSES=$(echo "$ALL_PROJECTS" | jq -r --arg name "$PROJECT_NAME" '
    .[] | select(.name == $name) | .environments[]?.compose[]? |
    {composeId, name: .name} | @base64
  ')

  if [ -z "$COMPOSES" ]; then
    echo "ERROR: Project '$PROJECT_NAME' not found or has no compose services" >&2
    exit 1
  fi

  for COMPOSE_B64 in $COMPOSES; do
    COMPOSE_ID=$(echo "$COMPOSE_B64" | base64 -d | jq -r '.composeId')
    COMPOSE_NAME=$(echo "$COMPOSE_B64" | base64 -d | jq -r '.name')

    # Get compose file content
    COMPOSE_YAML=$(curl -sf "$API_URL/compose.getConvertedCompose?composeId=$COMPOSE_ID" \
      -H "x-api-key: $API_KEY")

    # Extract images from YAML (handles both "image: foo" and "image: 'foo'" formats)
    IMAGES=$(echo "$COMPOSE_YAML" | grep -oE 'image:\s*["\x27]?[^"\x27\s]+["\x27]?' |
             sed -E "s/image:\s*['\"]?//g" | sed -E "s/['\"]$//g" | sort -u)

    if [ -z "$IMAGES" ]; then
      echo "[$PROJECT_NAME/$COMPOSE_NAME] No images found, skipping"
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
        echo "[$PROJECT_NAME/$COMPOSE_NAME] Updated: $IMAGE"
        CHANGED=1
      fi
    done

    if [ "$CHANGED" -eq 1 ]; then
      echo "[$PROJECT_NAME/$COMPOSE_NAME] Deploying..."
      curl -sf -X POST "$API_URL/compose.redeploy" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $API_KEY" \
        -d "{\"composeId\": \"$COMPOSE_ID\"}"
      echo
    fi
  done
done

echo "Done"
