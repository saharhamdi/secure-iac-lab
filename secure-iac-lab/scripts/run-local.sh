#!/usr/bin/env bash
# Exécute les contrôles Checkov en local.
# - versions "before" : des échecs sont ATTENDUS (non bloquant)
# - versions "after"  : aucun échec toléré (le script échoue sinon)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v checkov >/dev/null 2>&1; then
  echo "Checkov introuvable. Installez-le avec : pip install checkov" >&2
  exit 2
fi

status=0

echo "=== [1/4] Terraform BEFORE (échecs attendus) ==="
checkov -d terraform/before --framework terraform --compact --quiet || true

echo
echo "=== [2/4] Dockerfile BEFORE (échecs attendus) ==="
checkov -d docker/before --framework dockerfile --compact --quiet || true

echo
echo "=== [3/4] Terraform AFTER (doit réussir) ==="
if ! checkov -d terraform/after --framework terraform --compact --quiet; then
  echo "ECHEC : terraform/after contient des constats." >&2
  status=1
fi

echo
echo "=== [4/4] Dockerfile AFTER (doit réussir) ==="
if ! checkov -d docker/after --framework dockerfile --compact --quiet; then
  echo "ECHEC : docker/after contient des constats." >&2
  status=1
fi

echo
if [ "$status" -eq 0 ]; then
  echo "OK : les versions 'after' sont conformes."
else
  echo "KO : corrigez les versions 'after'."
fi
exit "$status"
