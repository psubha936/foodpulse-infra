#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
INFRA_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

cd "$INFRA_DIR"

usage() {
  cat <<'EOF'
FoodPulse Redis infrastructure helper

Usage:
  ./scripts/redis.sh <command>

Commands:
  pull          Download Redis and RedisInsight images
  start         Create/start Redis and RedisInsight
  recreate      Recreate both containers after config/password changes
  restart       Restart existing containers without changing configuration
  stop          Stop containers and preserve containers/volumes
  down          Remove containers/network and preserve named volumes
  status        Show Compose service status
  logs          Follow logs for both services
  logs-redis    Follow Redis logs only
  logs-ui       Follow RedisInsight logs only
  check         Test containers, authentication, Redis ping, and UI health
  cli           Open redis-cli and securely prompt for the password
  help          Show this help

This script intentionally has no volume-deletion command.
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command is missing: $1" >&2
    exit 1
  fi
}

require_podman() {
  require_command podman

  if ! podman info >/dev/null 2>&1; then
    echo "Podman is not reachable. On macOS run: podman machine start" >&2
    exit 1
  fi

  if ! podman compose version >/dev/null 2>&1; then
    echo "A Podman Compose provider is required." >&2
    exit 1
  fi
}

require_env() {
  if [ ! -f .env ]; then
    echo "Missing foodpulse-infra/.env" >&2
    echo "Run: cp .env.example .env, then set REDIS_PASSWORD." >&2
    exit 1
  fi

  if ! grep -Eq '^REDIS_PASSWORD=.+$' .env; then
    echo "REDIS_PASSWORD is missing or empty in foodpulse-infra/.env" >&2
    echo "Use exactly: REDIS_PASSWORD=your-local-password" >&2
    echo "Do not add spaces around the equals sign." >&2
    exit 1
  fi
}

container_is_running() {
  [ "$(podman inspect --format '{{.State.Running}}' "$1" 2>/dev/null || true)" = "true" ]
}

check_services() {
  require_command curl

  if ! container_is_running foodpulse-redis; then
    echo "FAIL: foodpulse-redis is not running" >&2
    exit 1
  fi

  if ! container_is_running foodpulse-redisinsight; then
    echo "FAIL: foodpulse-redisinsight is not running" >&2
    exit 1
  fi

  echo "1/4 Containers are running"

  unauthenticated_result=$(podman exec foodpulse-redis sh -c \
    'env -u REDISCLI_AUTH -u REDIS_PASSWORD redis-cli ping' 2>&1 || true)

  case "$unauthenticated_result" in
    *"NOAUTH Authentication required"*) ;;
    *)
      echo "FAIL: Redis accepted an unauthenticated ping" >&2
      echo "Recreate it after setting REDIS_PASSWORD: ./scripts/redis.sh recreate" >&2
      exit 1
      ;;
  esac

  echo "2/4 Unauthenticated access is rejected"

  authenticated_result=$(podman exec foodpulse-redis sh -c \
    'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ping' 2>/dev/null || true)

  if [ "$authenticated_result" != "PONG" ]; then
    echo "FAIL: authenticated Redis ping did not return PONG" >&2
    exit 1
  fi

  echo "3/4 Authenticated Redis ping passed"

  if ! curl --fail --silent http://127.0.0.1:5540/api/health/ >/dev/null; then
    echo "FAIL: RedisInsight health endpoint is unavailable" >&2
    exit 1
  fi

  echo "4/4 RedisInsight health check passed"
  echo "All FoodPulse Redis checks passed."
}

command_name=${1:-help}

case "$command_name" in
  help|-h|--help)
    usage
    exit 0
    ;;
esac

require_podman

case "$command_name" in
  pull)
    podman pull docker.io/redis:8.2.8-alpine
    podman pull docker.io/redis/redisinsight:latest
    ;;
  start)
    require_env
    podman compose up -d redis redisinsight
    podman compose ps
    ;;
  recreate)
    require_env
    podman compose up -d --force-recreate redis redisinsight
    podman compose ps
    ;;
  restart)
    require_env
    podman compose restart redis redisinsight
    podman compose ps
    ;;
  stop)
    podman compose stop redis redisinsight
    ;;
  down)
    podman compose down
    ;;
  status)
    podman compose ps
    ;;
  logs)
    podman compose logs --follow redis redisinsight
    ;;
  logs-redis)
    podman compose logs --follow redis
    ;;
  logs-ui)
    podman compose logs --follow redisinsight
    ;;
  check)
    require_env
    check_services
    ;;
  cli)
    if ! container_is_running foodpulse-redis; then
      echo "foodpulse-redis is not running. Run: ./scripts/redis.sh start" >&2
      exit 1
    fi
    podman exec -it foodpulse-redis redis-cli --askpass
    ;;
  *)
    echo "Unknown command: $command_name" >&2
    usage >&2
    exit 2
    ;;
esac
