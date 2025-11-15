#!/usr/bin/env bash
set -o errexit -o nounset -o xtrace -o pipefail
shopt -s inherit_errexit nullglob dotglob

# Handle Docker errors gracefully
if ! docker info >/dev/null 2>&1; then
  echo "Warning: Docker daemon not accessible" >&2
  exit 0
fi

# Only remove workspace contents if explicitly requested
if test "${CLEAN_WORKSPACE:-false}" = "true"; then
  rm -rf "${HOME:?}"/* "${GITHUB_WORKSPACE:?}"/*
fi

if test "${RUNNER_DEBUG:-0}" != '1'; then
  set +o xtrace 
fi

# Get all containers by name, handling potential errors
if ! all_containers=($(docker ps --all --format "{{.Names}}" 2>/dev/null)); then
  echo "Warning: Failed to list Docker containers" >&2
  exit 0
fi

protected_containers=()
if test "${PROTECTED_CONTAINER_NAMES:-[]}" != '[]'; then
  if ! container_names=$(jq -r '.[]' <<< "$PROTECTED_CONTAINER_NAMES" 2>/dev/null); then
    echo "Warning: Failed to parse container names" >&2
    exit 0
  fi
  readarray -t protected_containers <<< "$container_names"
fi

# Get self container name more reliably
if ! self_id=$(cat /etc/hostname 2>/dev/null); then
  echo "Warning: Failed to get hostname" >&2
  exit 0
fi
if ! self=$(docker ps --filter id="$self_id" --format "{{.Names}}" 2>/dev/null); then
  echo "Warning: Failed to get container name" >&2
  exit 0
fi
if test -n "$self"; then
  protected_containers+=("$self")
fi

if test "${#protected_containers[@]}" -eq "${#all_containers[@]}"; then
  echo 'No "extra" containers detected.' >&2
  exit 0
fi

# Build grep pattern more safely
grep_flags=()
for name in "${protected_containers[@]}"; do
  if test -n "$name"; then
    grep_flags+=('-e')
    grep_flags+=("$name")
  fi
done

# Remove containers with error handling
if test "${#grep_flags[@]}" -gt 0; then
  containers_to_remove=$(printf '%s\n' "${all_containers[@]}" | grep -Fv "${grep_flags[@]}" || true)
  if [ -n "$containers_to_remove" ]; then
    if ! echo "$containers_to_remove" | xargs -r docker rm --force 2>/dev/null; then
      echo "Warning: Failed to remove some containers" >&2
    fi
  fi
fi