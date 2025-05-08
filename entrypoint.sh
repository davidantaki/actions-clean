#!/usr/bin/env bash
set -o errexit -o nounset -o xtrace -o pipefail
shopt -s inherit_errexit nullglob dotglob

# Only remove workspace contents if explicitly requested
if test "${CLEAN_WORKSPACE:-false}" = "true"; then
  rm -rf "${HOME:?}"/* "${GITHUB_WORKSPACE:?}"/*
fi

if test "${RUNNER_DEBUG:-0}" != '1'; then
  set +o xtrace 
fi

# Get all containers, handling potential errors
if ! all_containers=($(docker ps --all --quiet 2>/dev/null)); then
  echo "Warning: Failed to list Docker containers" >&2
  exit 0
fi

protected_containers=()
if test "$PROECTED_CONTAINER_SERVICE_IDS" != '[]'; then
  if ! service_ids=$(jq -r '.[]' <<< "$PROECTED_CONTAINER_SERVICE_IDS" 2>/dev/null); then
    echo "Warning: Failed to parse service IDs" >&2
    exit 0
  fi
  readarray -t protected_containers <<< "$service_ids"
fi

# Get self container ID more reliably
if ! self=$(cat /etc/hostname 2>/dev/null); then
  echo "Warning: Failed to get hostname" >&2
  exit 0
fi
protected_containers+=("$self")

if test "${#protected_containers[@]}" -eq "${#all_containers[@]}"; then
  echo 'No "extra" containers detected.' >&2
  exit 0
fi

# Build grep pattern more safely
grep_flags=()
for id in "${protected_containers[@]}"; do
  if test -n "$id"; then
    grep_flags+=('-e')
    grep_flags+=("$(head -c 12 <<< "$id")")
  fi
done

# Remove containers with error handling
if test "${#grep_flags[@]}" -gt 0; then
  if ! printf '%s\n' "${all_containers[@]}" | grep -Fv "${grep_flags[@]}" | xargs -r docker rm --force; then
    echo "Warning: Failed to remove some containers" >&2
    exit 0
  fi
fi