#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
INFRA_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

cd "$INFRA_DIR"

usage() {
  cat <<'EOF'
FoodPulse Kafka infrastructure helper

Usage: ./scripts/kafka.sh <command> [argument]

Commands:
  pull                    Pull the pinned Kafka image
  start                   Create/start Kafka
  recreate                Recreate Kafka after Compose changes
  restart                 Restart the unchanged Kafka container
  stop                    Stop Kafka and preserve container/volume
  down                    Remove Compose containers/network; preserve volumes
  status                  Show Kafka status
  logs                    Follow Kafka logs
  check                   Verify broker API and list topics
  topics                  List topics
  create-topic <name>     Create a 3-partition local topic
  describe-topic <name>   Describe a topic
  producer <name>         Open an interactive console producer
  consumer <name>         Read a topic from the beginning
  help                    Show this help

No volume-deletion command is provided.
EOF
}

require_podman() {
  command -v podman >/dev/null 2>&1 || {
    echo "Podman is required" >&2
    exit 1
  }

  podman info >/dev/null 2>&1 || {
    echo "Podman is unavailable. Run: podman machine start" >&2
    exit 1
  }
}

require_kafka() {
  running=$(podman inspect --format '{{.State.Running}}' \
    foodpulse-kafka 2>/dev/null || true)

  if [ "$running" != "true" ]; then
    echo "foodpulse-kafka is not running. Run: ./scripts/kafka.sh start" >&2
    exit 1
  fi
}

require_topic_name() {
  if [ "$#" -lt 1 ] || [ -z "$1" ]; then
    echo "A topic name is required" >&2
    usage >&2
    exit 2
  fi
}

command_name=${1:-help}
topic_name=${2:-}

case "$command_name" in
  help|-h|--help)
    usage
    exit 0
    ;;
esac

require_podman

case "$command_name" in
  pull)
    podman pull docker.io/apache/kafka:4.3.1
    ;;
  start)
    podman compose up -d kafka
    podman compose ps
    ;;
  recreate)
    podman compose up -d --force-recreate kafka
    podman compose ps
    ;;
  restart)
    podman compose restart kafka
    podman compose ps
    ;;
  stop)
    podman compose stop kafka
    ;;
  down)
    podman compose down
    ;;
  status)
    podman compose ps
    ;;
  logs)
    podman compose logs --follow kafka
    ;;
  check)
    require_kafka
    podman exec foodpulse-kafka \
      /opt/kafka/bin/kafka-broker-api-versions.sh \
      --bootstrap-server kafka:29092 >/dev/null
    podman exec foodpulse-kafka \
      /opt/kafka/bin/kafka-topics.sh \
      --bootstrap-server kafka:29092 --list
    echo "FoodPulse Kafka check passed."
    ;;
  topics)
    require_kafka
    podman exec foodpulse-kafka \
      /opt/kafka/bin/kafka-topics.sh \
      --bootstrap-server kafka:29092 --list
    ;;
  create-topic)
    require_topic_name "$topic_name"
    require_kafka
    podman exec foodpulse-kafka \
      /opt/kafka/bin/kafka-topics.sh \
      --bootstrap-server kafka:29092 \
      --create --if-not-exists \
      --topic "$topic_name" \
      --partitions 3 \
      --replication-factor 1
    ;;
  describe-topic)
    require_topic_name "$topic_name"
    require_kafka
    podman exec foodpulse-kafka \
      /opt/kafka/bin/kafka-topics.sh \
      --bootstrap-server kafka:29092 \
      --describe --topic "$topic_name"
    ;;
  producer)
    require_topic_name "$topic_name"
    require_kafka
    podman exec -it foodpulse-kafka \
      /opt/kafka/bin/kafka-console-producer.sh \
      --bootstrap-server kafka:29092 \
      --topic "$topic_name"
    ;;
  consumer)
    require_topic_name "$topic_name"
    require_kafka
    podman exec -it foodpulse-kafka \
      /opt/kafka/bin/kafka-console-consumer.sh \
      --bootstrap-server kafka:29092 \
      --topic "$topic_name" \
      --from-beginning
    ;;
  *)
    echo "Unknown command: $command_name" >&2
    usage >&2
    exit 2
    ;;
esac