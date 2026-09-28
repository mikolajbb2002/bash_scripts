# Self-Healing Toolkit Lab — Student Version

This package provides the lab environment for the **Bash – Self-Healing Toolkit** task.

## Important

The self-healing script is **not included** in this package.

Your task is to implement:

```bash
self-heal.sh
```

based on the assignment requirements.

## Included files

- `app.py` — fake HTTP service exposing `/health`
- `payment-api.service` — `systemd` unit
- `setup_lab.sh` — installs the lab locally
- `failure_scenarios.sh` — triggers test failures

## Requirements

- Linux machine with `systemd`
- Python 3
- `curl`
- `ss` or equivalent
- root or sudo privileges

### macOS

The full lab cannot run directly on macOS because it uses Linux `systemd`.
Run the setup and failure scenarios inside a Linux VM running `systemd`, or on
a Linux host. Creating `/etc/systemd/system` on macOS will not resolve this.

To try only the HTTP API on macOS, run this from `code_for_student`:

```bash
python3 app.py
```

In another terminal, run `curl http://localhost:8080/health`. Stop the API with
Ctrl+C. This preview does not support the lab's service management exercises.

## Quick start

```bash
chmod +x *.sh app.py
sudo bash setup_lab.sh
```

## Verify the setup

```bash
systemctl status payment-api
curl http://localhost:8080/health
ss -ltnp | grep 8080
```

Expected healthy response:

```json
{"status":"UP"}
```

## What you need to implement

Create a script named:

```bash
self-heal.sh
```

Your script should support at least:
- `check`
- `heal`
- `diagnose`

It should:
- verify `systemctl` service health
- verify listening port
- verify HTTP health endpoint
- restart service when needed
- collect diagnostics if recovery fails

## Failure scenarios for validation

### Stop the service
```bash
sudo bash failure_scenarios.sh stop-service
```

### Break health endpoint
```bash
sudo bash failure_scenarios.sh break-health
```

### Run on wrong port
```bash
sudo bash failure_scenarios.sh wrong-port
```

### Restore healthy state
```bash
sudo bash failure_scenarios.sh restore-health
sudo bash failure_scenarios.sh restore-port
```

## Suggested student flow

1. Install the lab
2. Verify healthy state
3. Implement `self-heal.sh`
4. Test `check` mode on healthy service
5. Stop the service and test `heal`
6. Break health endpoint and test unhealthy-but-running case
7. Move service to wrong port and verify port mismatch detection
8. Force recovery failure and verify diagnostics

## Cleanup

```bash
sudo systemctl stop payment-api
sudo systemctl disable payment-api
sudo rm -f /etc/systemd/system/payment-api.service
sudo rm -rf /etc/systemd/system/payment-api.service.d
sudo systemctl daemon-reload
sudo rm -rf /opt/payment-api-lab
```
