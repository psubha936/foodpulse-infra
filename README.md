# foodpulse-infra
infa Podman, Kafka, Redis, MongoDB

Local host ports are registered in `../implementation/SERVICE_PORTS.md`. Kafka UI
uses `http://localhost:18080`; port `8080` is reserved for `foodpulse-proxy`.

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
