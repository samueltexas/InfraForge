#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-quick}"
cd "$ROOT"

case "$MODE" in
  quick|full) ;;
  *) echo "Usage: ./scripts/validate.sh [quick|full]" >&2; exit 2 ;;
esac

if [[ -x "$ROOT/.venv/bin/python" ]]; then
  PYTHON="$ROOT/.venv/bin/python"
else
  PYTHON="$(command -v python3)"
fi

echo "=== INFRAFORGE VALIDATION: $MODE ==="

"$PYTHON" -m unittest discover -s tests -p "test_*.py" -v

if [[ "$MODE" == "quick" ]]; then
  echo "Quick validation passed."
  exit 0
fi

command -v docker >/dev/null || {
  echo "Docker is required for full validation." >&2
  exit 1
}

docker info >/dev/null 2>&1 || {
  echo "Start Docker Desktop before full validation." >&2
  exit 1
}

terraform_run() {
  local directory="$1"
  shift
  docker run --rm     --mount "type=bind,source=$ROOT,target=/workspace"     -w "/workspace/$directory"     --entrypoint terraform     hashicorp/terraform:1.14.0     "$@"
}

echo "=== TERRAFORM FORMAT ==="
terraform_run . fmt -check -recursive -no-color

DIRECTORIES=(
  modules/networking
  modules/identity
  modules/keyvault
  modules/monitoring
  examples/networking
  examples/identity
  examples/keyvault
  examples/monitoring
  examples/integrated
)

for directory in "${DIRECTORIES[@]}"; do
  echo "=== VALIDATING $directory ==="
  terraform_run "$directory" init     -backend=false -input=false -lockfile=readonly -no-color
  terraform_run "$directory" validate -no-color
done

echo "Full validation passed."
