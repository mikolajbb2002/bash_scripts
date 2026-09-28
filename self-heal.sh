#!/bin/bash

cd ~/code_for_student || exit 2

service="$1"
port="$2"
health_url="$3"
mode="$4"
wait_seconds="${5:-10}"   

if [[ -z "$service" || -z "$port" || -z "$health_url" || -z "$mode" ]]; then
  echo "[ERROR] Usage: $0 --service <name> --port <port> --health-url <url> --mode <check|heal|diagnose>" >&2
  exit 2
fi

if [[ "$mode" != "check" && "$mode" != "heal" && "$mode" != "diagnose" ]]; then
  echo "[ERROR] Mode must be one of: check, heal, diagnose" >&2
  exit 2
fi

run_checks() {
  echo "[INFO] Checking service: $service"

  if systemctl is-active --quiet "$service"; then
    echo "[INFO] Service is active"
    status_ok=true
  else
    echo "[ERROR] Service is not active"
    status_ok=false
  fi

  if sudo ss -ltnH "sport = :$port" | grep -q .; then
    echo "[INFO] Port $port is listening"
    port_ok=true
  else
    echo "[ERROR] Port $port is not listening"
    port_ok=false
  fi

  if curl --fail --silent --max-time 3 "$health_url" > /dev/null; then
    echo "[INFO] Health endpoint OK"
    health_ok=true
  else
    echo "[ERROR] Health endpoint check failed"
    health_ok=false
  fi

  if [[ "$status_ok" == true && "$port_ok" == true && "$health_ok" == true ]]; then
    return 0
  else
    return 1
  fi
}

collect_diagnostics() {
  mkdir -p ./reports
  log_file="./reports/${service}-$(date +%Y-%m-%d-%H-%M-%S).log"

  {
    date
    echo "service=$service port=$port health_url=$health_url mode=$mode"
    echo "--- systemctl status ---"
    sudo systemctl status "$service" --no-pager --full
    echo "--- journalctl (last 100) ---"
    sudo journalctl -u "$service" -n 100 --no-pager
    echo "--- port inspection ---"
    sudo ss -ltnp
    echo "--- health check ---"
    curl --show-error --fail --max-time 3 "$health_url"
    echo "--- summary ---"
    echo "status_ok=$status_ok port_ok=$port_ok health_ok=$health_ok"
  } > "$log_file" 2>&1

  echo "[INFO] Diagnostic report saved to $log_file"
}

# --- recovery: restart, wait, re-check ---
attempt_recovery() {
  echo "[INFO] Attempting recovery: restarting service"
  sudo systemctl restart "$service"
  echo "[INFO] Waiting $wait_seconds seconds before re-check"
  sleep "$wait_seconds"
  run_checks
}

# ================= MAIN =================
run_checks
healthy=$?

case "$mode" in
  check)
    if [[ $healthy -eq 0 ]]; then
      echo "[INFO] Service healthy"
      exit 0
    else
      echo "[ERROR] Service unhealthy"
      exit 1
    fi
    ;;

  diagnose)
    collect_diagnostics
    exit $([[ $healthy -eq 0 ]] && echo 0 || echo 1)
    ;;

  heal)
    if [[ $healthy -eq 0 ]]; then
      echo "[INFO] Service already healthy"
      exit 0
    fi

    attempt_recovery
    healthy=$?

    if [[ $healthy -eq 0 ]]; then
      echo "[INFO] Recovery successful"
      exit 0
    else
      echo "[ERROR] Recovery failed, collecting diagnostics"
      collect_diagnostics
      exit 1
    fi
    ;;
esac