#!/usr/bin/env bash
# Generate properties-file secrets for ctai-configuration.properties (GitHub state + SSO JWT).
set -euo pipefail

GITHUB_STATE_BYTES=24
SSO_JWT_BYTES=32
MIN_SECRET_BYTES=16

usage() {
  cat <<'EOF'
Usage: generate-properties-secrets.sh [options]

Generate random secrets for ctai-configuration.properties.

These values are stored in the properties file (not in a separate Kubernetes
Secret). They must differ from each other and from the protected storage master
key.

Output uses URL-safe base64 (no padding), matching the config wizard:
  github_state_secret — 24 random bytes (GitHub OAuth state signing)
  sso_jwt_secret      — 32 random bytes (SSO session JWT signing)

Options:
  --github-state-only   Emit github_state_secret only
  --sso-jwt-only        Emit sso_jwt_secret only
  --validate-github V   Validate an existing github_state_secret value
  --validate-jwt V      Validate an existing sso_jwt_secret value
  -h, --help            Show this help

Examples:
  ./generate-properties-secrets.sh
  ./generate-properties-secrets.sh --validate-github 'abc' --validate-jwt 'def'
EOF
}

random_secret_b64url() {
  local nbytes="$1"
  openssl rand "$nbytes" | base64 | tr -d '\n' | tr '+/' '-_' | tr -d '='
}

validate_secret() {
  local label="$1"
  local value="$2"
  local min_bytes="$3"

  if [[ -z "$value" ]]; then
    echo "Error: ${label} is empty" >&2
    return 1
  fi
  if [[ ${#value} -lt $((min_bytes * 4 / 3)) ]]; then
    echo "Error: ${label} is too short (use at least ${min_bytes} random bytes)" >&2
    return 1
  fi
  if ! [[ "$value" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "Error: ${label} must use URL-safe base64 characters (A-Za-z0-9_-)" >&2
    return 1
  fi
  echo "Valid: ${label}"
  return 0
}

generate_github_state_secret() {
  random_secret_b64url "$GITHUB_STATE_BYTES"
}

generate_sso_jwt_secret() {
  random_secret_b64url "$SSO_JWT_BYTES"
}

emit_pair() {
  local github jwt
  github="$(generate_github_state_secret)"
  jwt="$(generate_sso_jwt_secret)"
  while [[ "$github" == "$jwt" ]]; do
    jwt="$(generate_sso_jwt_secret)"
  done
  echo "github_state_secret=${github}"
  echo "sso_jwt_secret=${jwt}"
  cat <<EOF >&2

Paste these lines into ctai-configuration.properties (replace the placeholders).
Store the file securely — it contains deployment secrets.
Each run of the script generates new values. Only run this and update your
ctai-configuration.properties unless it is intentional; do not rotate
sso_jwt_secret after users have logged in unless you intend to invalidate
existing sessions.
EOF
}

main() {
  local mode="pair"
  local validate_github=""
  local validate_jwt=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --github-state-only)
        mode="github"
        shift
        ;;
      --sso-jwt-only)
        mode="jwt"
        shift
        ;;
      --validate-github)
        mode="validate"
        validate_github="${2:?--validate-github requires a value}"
        shift 2
        ;;
      --validate-jwt)
        mode="validate"
        validate_jwt="${2:?--validate-jwt requires a value}"
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
    github)
      echo "github_state_secret=$(generate_github_state_secret)"
      ;;
    jwt)
      echo "sso_jwt_secret=$(generate_sso_jwt_secret)"
      ;;
    validate)
      local status=0
      if [[ -n "$validate_github" ]]; then
        validate_secret "github_state_secret" "$validate_github" "$MIN_SECRET_BYTES" || status=1
      fi
      if [[ -n "$validate_jwt" ]]; then
        validate_secret "sso_jwt_secret" "$validate_jwt" "$MIN_SECRET_BYTES" || status=1
      fi
      if [[ -z "$validate_github" && -z "$validate_jwt" ]]; then
        echo "Error: use --validate-github and/or --validate-jwt" >&2
        usage >&2
        exit 1
      fi
      if [[ -n "$validate_github" && -n "$validate_jwt" && "$validate_github" == "$validate_jwt" ]]; then
        echo "Error: github_state_secret and sso_jwt_secret must be different" >&2
        status=1
      fi
      exit "$status"
      ;;
    pair)
      emit_pair
      ;;
  esac
}

main "$@"
