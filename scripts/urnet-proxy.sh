#!/bin/bash
# URnetwork proxy helper

set -euo pipefail

API_URL="https://api.bringyour.com"
JWT_FILE="$HOME/.urnetwork_jwt"

die() { echo "Error: $*" >&2; exit 1; }

load_env() {
  if [[ -f .env ]]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
  fi
}

require_tools() {
  command -v curl >/dev/null || die "curl is required"
  command -v jq >/dev/null || die "jq is required"
}

auth_with_code() {
  local code="${1:-${AUTH_CODE:-${auth_code:-}}}"
  if [[ -z "$code" ]]; then
    echo "Get auth code from https://ur.io"
    read -rp "Enter auth code: " code
  fi
  JWT=$(curl -fsS -X POST "$API_URL/auth/code-login" -H "Content-Type: application/json" \
    -d "{\"auth_code\":\"$code\"}" | jq -r '.by_jwt')
  [[ -n "$JWT" && "$JWT" != "null" ]] || die "auth failed"
  echo "$JWT" > "$JWT_FILE"
  chmod 600 "$JWT_FILE"
  echo "Authenticated. JWT saved to $JWT_FILE"
}

load_jwt() {
  if [[ -n "${URNETWORK_JWT:-}" ]]; then
    JWT="$URNETWORK_JWT"
  elif [[ -f "$JWT_FILE" ]]; then
    JWT=$(cat "$JWT_FILE")
  elif [[ -n "${AUTH_CODE:-${auth_code:-}}" ]]; then
    auth_with_code "${AUTH_CODE:-${auth_code:-}}"
  else
    die "no JWT/auth code found. Set AUTH_CODE in .env or run: $(basename "$0") auth <code>"
  fi
}

find_locations() {
  local query="${1:-}"
  echo "Searching locations: $query"
  curl -fsS -X POST "$API_URL/network/find-provider-locations" \
    -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" \
    -d "{\"query\":\"$query\"}" | jq -r '.locations[:10] | .[] |
      "\(.name) (\(.location_type)) - \(.provider_count) providers | ID: \(.location_id)"'
}

create_proxy_request() {
  local location="$1"
  local wg_enable="$2"
  local description="$3"
  curl -fsS -X POST "$API_URL/network/auth-client" \
    -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" \
    -d "{
      \"description\": \"$description\",
      \"proxy_config\": {
        \"https_require_auth\": true,
        \"enable_wg\": $wg_enable,
        \"initial_device_state\": { \"country_code\": \"$location\" }
      }
    }"
}

response_error() {
  local response="$1"
  printf '%s' "$response" | jq -r '.error.message // .message // empty' 2>/dev/null || true
}

validate_positive_integer() {
  local value="$1"
  local label="$2"

  [[ "$value" =~ ^[0-9]+$ ]] || die "$label must be a positive integer"
  (( 10#$value > 0 )) || die "$label must be greater than 0"
}

create_proxy_request_with_status() {
  local location="$1"
  local wg_enable="$2"
  local description="$3"

  curl -sS -X POST "$API_URL/network/auth-client" \
    -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" \
    -d "{
      \"description\": \"$description\",
      \"proxy_config\": {
        \"https_require_auth\": true,
        \"enable_wg\": $wg_enable,
        \"initial_device_state\": { \"country_code\": \"$location\" }
      }
    }" \
    -w $'\n%{http_code}'
}

is_transient_status() {
  local status="$1"
  [[ "$status" == "429" || "$status" =~ ^5[0-9][0-9]$ ]]
}

create_proxy_with_retry() {
  local location="$1"
  local description="$2"
  local index="$3"
  local total="$4"
  local max_attempts_raw="${PROXY_CREATE_MAX_ATTEMPTS:-4}"
  local max_attempts
  local attempt=1
  local retry_delay

  validate_positive_integer "$max_attempts_raw" "PROXY_CREATE_MAX_ATTEMPTS"
  max_attempts=$((10#$max_attempts_raw))

  while (( attempt <= max_attempts )); do
    local raw response status err curl_status

    if raw=$(create_proxy_request_with_status "$location" "false" "$description"); then
      status="${raw##*$'\n'}"
      response="${raw%$'\n'*}"

      if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
        printf '%s' "$response"
        return 0
      fi

      err=$(response_error "$response")
      [[ -n "$err" ]] || err="HTTP $status"

      if is_transient_status "$status" && (( attempt < max_attempts )); then
        retry_delay=$((attempt * 2))
        echo "[$index/$total] transient API error ($status): $err. Retrying in ${retry_delay}s..." >&2
        sleep "$retry_delay"
        ((attempt++))
        continue
      fi

      echo "[$index/$total] request failed ($status): $err" >&2
      return 1
    else
      curl_status=$?

      if (( attempt < max_attempts )); then
        retry_delay=$((attempt * 2))
        echo "[$index/$total] network error (curl exit $curl_status). Retrying in ${retry_delay}s..." >&2
        sleep "$retry_delay"
        ((attempt++))
        continue
      fi

      echo "[$index/$total] network error after $max_attempts attempts (curl exit $curl_status)" >&2
      return 1
    fi
  done

  return 1
}

extract_proxy_markdown_fields() {
  local response="$1"

  printf '%s' "$response" | jq -er '[
    .proxy_config_result.https_proxy_url,
    .proxy_config_result.proxy_host,
    .proxy_config_result.https_proxy_port,
    .proxy_config_result.auth_token
  ] | @tsv'
}

create_proxy() {
  local location="$1"
  local proto="${2:-socks}"
  local wg_enable="false"
  [[ "$proto" == "wg" || "$proto" == "wireguard" ]] && wg_enable="true"

  local response err result auth_token proxy_host socks_port http_port https_port
  response=$(create_proxy_request "$location" "$wg_enable" "Proxy: $location")
  err=$(response_error "$response")
  [[ -z "$err" ]] || die "$err"

  result=$(echo "$response" | jq -r '.proxy_config_result')
  auth_token=$(echo "$result" | jq -r '.auth_token')
  proxy_host=$(echo "$result" | jq -r '.proxy_host')
  socks_port=$(echo "$result" | jq -r '.socks_proxy_port // 8080')
  http_port=$(echo "$result" | jq -r '.http_proxy_port // 8081')
  https_port=$(echo "$result" | jq -r '.https_proxy_port // 8082')

  cat <<EOF
SOCKS5: socks5h://$proxy_host:$socks_port
HTTP:   http://$proxy_host:$http_port
HTTPS:  https://$proxy_host:$https_port
Auth token (username, empty password):
$auth_token
Usage:
curl --proxy http://$proxy_host:$http_port --proxy-user "$auth_token:" https://api.ipify.org
EOF

  echo "$response" > "$HOME/.urnetwork_proxy.json"
  echo "Saved to $HOME/.urnetwork_proxy.json"
}

create_batch_markdown() {
  local count="${1:-${PROXY_COUNT:-100}}"
  local country="${2:-${PROXY_COUNTRY:-us}}"
  local country_upper="${country^^}"
  local output="${3:-${PROXY_OUTPUT:-us-https-proxies-$(date +%Y%m%d-%H%M%S).md}}"
  local existing max_clients=128 available

  validate_positive_integer "$count" "count"
  count=$((10#$count))

  existing=$(curl -fsS "$API_URL/network/clients" -H "Authorization: Bearer $JWT" | jq '.clients | length')
  available=$((max_clients - existing))
  (( count <= available )) || die "requested $count proxies; only $available client slots available"

  [[ ! -L "$output" ]] || die "output path must not be a symlink"
  : > "$output"
  chmod 600 "$output"

  {
    echo "# URnetwork HTTPS Proxies (${country_upper})"
    echo
    echo "- Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo "- Count: $count"
    echo "- Security: file mode set to 600 (contains proxy credentials)"
    echo
    echo "| # | HTTPS Proxy URL | Proxy Host | HTTPS Port | Auth Token |"
    echo "|---:|---|---|---:|---|"
  } >> "$output"

  for i in $(seq 1 "$count"); do
    local response row https_url host https_port auth_token

    if ! response=$(create_proxy_with_retry "$country" "${country_upper} HTTPS Proxy #$i" "$i" "$count"); then
      echo "Batch failed at [$i/$count]. Partial file kept intentionally: $output" >&2
      return 1
    fi

    if ! row=$(extract_proxy_markdown_fields "$response"); then
      echo "[$i/$count] invalid API response shape; expected proxy_config_result fields" >&2
      echo "Batch failed at [$i/$count]. Partial file kept intentionally: $output" >&2
      return 1
    fi

    IFS=$'\t' read -r https_url host https_port auth_token <<< "$row"
    printf '| %d | `%s` | `%s` | %s | `%s` |\n' "$i" "$https_url" "$host" "$https_port" "$auth_token" >> "$output"
    echo "[$i/$count] created"
    sleep 0.2
  done

  echo "Done. Markdown saved to: $output"
  echo "Warning: file contains auth tokens; keep it secure and do not commit it."
}

quick() { create_proxy "${1:-vn}" "socks"; }

help() {
  cat <<'EOF'
URnetwork Proxy Creator

Commands:
  auth [code]                             Authenticate with code from https://ur.io
  find <query>                            Search locations (e.g., US)
  create <loc> [proto]                    Create proxy (socks|http|https|wg)
  batch-md [count] [country] [output.md]  Create HTTPS proxies and write Markdown (chmod 600)
  quick [loc]                             Quick SOCKS proxy (default: vn)

Batch behavior:
  - count must be a positive integer
  - output markdown keeps sensitive auth tokens
  - on mid-run failure, command exits non-zero and keeps partial output file

Examples:
  ./scripts/urnet-proxy.sh auth
  ./scripts/urnet-proxy.sh batch-md 100 us us-https-proxies.md
EOF
}

load_env
require_tools

case "${1:-help}" in
  auth) auth_with_code "${2:-}" ;;
  find) load_jwt; find_locations "${2:-}" ;;
  create) load_jwt; create_proxy "${2:-us}" "${3:-}" ;;
  batch-md) validate_positive_integer "${2:-${PROXY_COUNT:-100}}" "count"; load_jwt; create_batch_markdown "${2:-}" "${3:-}" "${4:-}" ;;
  quick) load_jwt; quick "${2:-}" ;;
  *) help ;;
esac
