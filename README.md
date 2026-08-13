# foodpulse-infra
infa Podman, Kafka, Redis, MongoDB

## Redis commands

Use the infrastructure helper from this repository:

```bash
./scripts/redis.sh help
./scripts/redis.sh pull
./scripts/redis.sh start
./scripts/redis.sh check
./scripts/redis.sh cli
./scripts/redis.sh stop
```

Run `recreate` instead of `restart` after changing `.env` or `compose.yaml`:

```bash
./scripts/redis.sh recreate
```

The helper does not provide a volume-deletion command.
