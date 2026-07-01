#!/usr/bin/env bash
# Generate or validate the protected storage master key (32-byte AES, base64).
set -euo pipefail

KEY_B64_ENV="CTAI_PROTECTED_STORAGE_MASTER_KEY_B64"
KEY_VERSION_ENV="CTAI_PROTECTED_STORAGE_MASTER_KEY_VERSION"
DEFAULT_SECRET_NAME="ctai-master-key"

usage() {
  cat <<'EOF'
Usage: generate-master-key.sh [options]

Generate a protected storage master key for on-prem CodeTogether installs.

The key is a random 32-byte AES key, encoded as standard base64 (44 characters).
CodeTogether uses it to encrypt sensitive information stored in Postgres (for
example GitHub app credentials, SMTP passwords, and AI API keys). It is not
stored in ctai-configuration.properties.

Generate this key once per deployment environment against a particular database
and configured schemas. If the key changes after
data has been encrypted, existing secrets in the database cannot be decrypted.

Options:
  --k8s-secret-yaml     Emit a Kubernetes Secret manifest (recommended for Helm)
  --secret-name NAME    Secret metadata.name (default: ctai-master-key)
  --validate B64        Validate an existing base64 key (exit 0 if 32 bytes)
  -h, --help            Show this help

Examples:
  ./generate-master-key.sh --k8s-secret-yaml --secret-name ctai-master-key | kubectl apply -f -
  ./generate-master-key.sh --validate 'bG9jYWwtZGV2ZWxvcG1lbnQtcHJvdGVjdGVkLWtleSE='
EOF
}

generate_key_b64() {
  openssl rand 32 | base64 | tr -d '\n'
}

validate_key_b64() {
  local b64="$1"
  if [[ -z "$b64" ]]; then
    echo "Error: base64 value is empty" >&2
    return 1
  fi
  local decoded
  if ! decoded="$(printf '%s' "$b64" | base64 -d 2>/dev/null)"; then
    echo "Error: invalid base64" >&2
    return 1
  fi
  local len="${#decoded}"
  if [[ "$len" -ne 32 ]]; then
    echo "Error: decoded length is ${len} bytes (expected 32)" >&2
    return 1
  fi
  echo "Valid: 32-byte protected storage master key"
  return 0
}

emit_k8s_secret_yaml() {
  local secret_name="$1"
  local key_b64="$2"
  cat <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${secret_name}
type: Opaque
stringData:
  ${KEY_B64_ENV}: ${key_b64}
  ${KEY_VERSION_ENV}: v1
EOF
}

print_helm_hint() {
  local secret_name="$1"
  cat <<EOF

Next steps (Helm):
  1. Save the base64 value above in your password manager (disaster recovery).
  2. Apply the Kubernetes Secret (if you have not already):
       kubectl apply -f ctai-master-key-secret.yaml -n <namespace>
  3. Install or upgrade the chart with:
       --set masterKey.source=secret \\
       --set masterKey.existingSecret=${secret_name}

Pair this Secret with your Postgres backup — restore both before starting the server.
EOF
}

main() {
  local mode="generate"
  local secret_name="$DEFAULT_SECRET_NAME"
  local validate_input=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --k8s-secret-yaml)
        mode="k8s"
        shift
        ;;
      --secret-name)
        secret_name="${2:?--secret-name requires a value}"
        shift 2
        ;;
      --validate)
        mode="validate"
        validate_input="${2:?--validate requires a base64 value}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

  case "$mode" in
    validate)
      validate_key_b64 "$validate_input"
      ;;
    k8s)
      local key_b64
      key_b64="$(generate_key_b64)"
      emit_k8s_secret_yaml "$secret_name" "$key_b64"
      echo "" >&2
      echo "Generated a new 32-byte AES master key." >&2
      echo "Save this base64 value in your password manager:" >&2
      echo "  ${key_b64}" >&2
      echo "" >&2
      echo "Apply the manifest above, then point Helm at the Secret:" >&2
      echo "  kubectl apply -f - -n <namespace>   # pipe this script's stdout" >&2
      echo "  helm install ... --set masterKey.source=secret --set masterKey.existingSecret=${secret_name}" >&2
      ;;
    generate)
      local key_b64
      key_b64="$(generate_key_b64)"
      echo "Protected storage master key (32-byte AES, base64):"
      echo "  ${key_b64}"
      echo ""
      echo "Run this script only once per environment (per database and schemas)."
      echo "Each run creates a different key."
      echo "If you already encrypted data with a previous key, you must reuse that key."
      echo ""
      echo "Printing the key alone does not configure Helm. To create the Kubernetes"
      echo "Secret and wire it into the chart, re-run with --k8s-secret-yaml:"
      echo "  ./generate-master-key.sh --k8s-secret-yaml --secret-name ${secret_name} > ctai-master-key-secret.yaml"
      print_helm_hint "$secret_name"
      ;;
  esac
}

main "$@"
