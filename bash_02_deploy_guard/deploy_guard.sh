#!/bin/bash

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${LAB_DIR}/service.pid"
STATE_DIR="${LAB_DIR}/state"
CURRENT_VERSION_FILE="${STATE_DIR}/current_version"
BROKEN_V2="${BROKEN_V2:-false}"
LOG_FILE="${LAB_DIR}/service.log"

service="$1"
version="$2"
health_url="$3"
delay="$4"
max_retries="${5:-10}"


if [[ -z "$service" || -z "$version" || -z "$health_url" || -z "$delay" ]]; then
  echo "[ERROR] Usage: $0 --service <name> --version <version> --health-url <url> --delay <as number>" >&2
  exit 2
fi

if [[ "$version" != "v1" && "$version" != "v2" ]]; then
  echo "[ERROR] Version must be one of: v1 or v2" >&2
  exit 2
fi

if ! [[ "$delay" =~ ^[0-9]+$ ]]; then
  echo "[ERROR] Delay must be a non-negative integer" >&2
  exit 2
fi

if ! [[ "$max_retries" =~ ^[0-9]+$ ]] || (( max_retries < 1 )); then
  echo "[ERROR] max_retries must be an integer >= 1" >&2
  exit 2
fi

mkdir -p "${STATE_DIR}/instances"

health_check(){
    for ((attempt =1; attempt <= max_retries; attempt ++)); do
        curl --fail --silent --show-error --max-time 3 "$health_url" > /dev/null && return 0
        sleep 1
    done

    return 1

}

list_instances(){
    echo "=== Deployment State ==="
    if [[ -f "${CURRENT_VERSION_FILE}" ]]; then
    echo "current_version=$(cat "${CURRENT_VERSION_FILE}")"
    fi
    for f in "${STATE_DIR}"/instances/*.version; do
    [[ -e "$f" ]] || continue
    echo "$(basename "$f" .version)=$(cat "$f")"
    done
}

deploy_instance() {
    local n="$1"
    local app="${LAB_DIR}/app_${version}.py"
    echo "[INFO] Deploying $version to instance-$n"
    BROKEN_V2="$BROKEN_V2" nohup python3 "$app" > "${STATE_DIR}/instances/instance-${n}.log" 2>&1 &
    echo $! > "${STATE_DIR}/instances/instance-${n}.pid"
    printf '%s\n' "$version" > "${STATE_DIR}/instances/instance-${n}.version"
    echo "[INFO] Version [$version] deployed to instance-$n"
 
}

rollback() {
  local failed_n="$1"
  local target_version
  target_version="$(cat "$CURRENT_VERSION_FILE" 2>/dev/null || echo v1)"

  echo "[WARNING] Rolling back deployment to $target_version" 

  for ((i=1;i<=failed_n;i++)); do
    local pid_file="${STATE_DIR}/instances/instance-{$i}.pid"
    if [[ -f "$pid_file" ]]; then 
      kill "$(cat "$pid_file")" 2>/dev/null
    fi
    local app="${LAB_DIR}/app_${target_version}.py"
    BROKEN_V2=false nohup python3 "$app" > "${STATE_DIR}/instances/instance-${i}.log" 2>&1 &
    echo $! > "$pid_file"
    printf '%s\n' "$target_version" > "${STATE_DIR}/instances/instance-${i}.version"
  done
  sleep "$delay"
  if health_check; then
    echo "[INFO] Rollback successful"
  else
    echo "[ERROR] Rollback failed"
    exit 1
  fi
}

for n in 1 2 3; do 
deploy_instance "$n"

sleep "$delay"
    
if ! health_check; then
    echo "[ERROR] Health check failed on instance-"$n""
    rollback "$n"
    exit 1
fi

    echo "[INFO] Health check passed on instance-"$n""
    list_instances
done

echo "[INFO] Deployment successful"