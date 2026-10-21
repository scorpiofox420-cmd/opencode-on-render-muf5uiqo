#!/usr/bin/env bash
# Legacy, live-production Java ThingSpace order-server build/run helper.
# This is NOT the OpenCode host or its static dashboard. The real Java backend
# and pom.xml must be restored before build/all can work.
# Usage: ./deploy-live.sh [build|run|all]  (default: all)
# Only source a local .env that you trust: it is executable shell code.

# Disable tracing before handling configuration, including inherited tracing.
set +vx
set -euo pipefail

# Validate the action before changing directories, loading .env, or any checks.
ACTION="${1-all}"
case "$ACTION" in
  build|run|all) ;;
  *) printf 'Usage: ./deploy-live.sh [build|run|all]\n' >&2; exit 2 ;;
esac
if (( $# > 1 )); then
  printf 'Usage: ./deploy-live.sh [build|run|all]\n' >&2
  exit 2
fi
readonly ACTION

err() { printf 'Error: %s\n' "$1" >&2; exit 1; }

if ! PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" 2>/dev/null; then
  err "Cannot locate the script directory."
fi
readonly PROJECT_DIR
cd -- "$PROJECT_DIR" 2>/dev/null || err "Cannot enter the script directory."

# Fail before loading secrets or looking for tools when the backend is absent.
if [[ "$ACTION" != run && ! -f pom.xml ]]; then
  err "Cannot build: missing pom.xml. The static dashboard is not the Java ThingSpace order server; restore the real backend sources and Maven build manifest first."
fi

select_jar() {
  local candidate count=0
  JAR=''
  # No ls/head pipeline: zero matches and multiple versions must be explicit.
  shopt -s nullglob
  for candidate in target/thingspace-order-server-*.jar; do
    case "$candidate" in
      *-sources.jar|*-javadoc.jar|*-tests.jar|*-plain.jar|*.original.jar) continue ;;
    esac
    JAR="$candidate"
    count=$((count + 1))
  done
  shopt -u nullglob
  case "$count" in
    0) err "No order-server JAR found under target/. The static dashboard is not a runnable Java backend." ;;
    1) ;;
    *) err "Multiple order-server JARs found under target/. Refusing to choose a version; keep exactly one runnable server JAR there." ;;
  esac
  [[ -f "$JAR" && -r "$JAR" && -s "$JAR" ]] || err "The selected order-server JAR is not a readable, nonempty regular file."
}

# A prebuilt server can run without pom.xml, Maven, or a local .env.
if [[ "$ACTION" == run ]]; then
  select_jar
fi

# Environment-injected secrets work without .env. Never print file contents.
if [[ -e .env || -L .env ]]; then
  [[ -f .env && -r .env ]] || err "Local .env exists but is not a readable regular file."
  set -a
  if source ./.env >/dev/null 2>&1; then
    set +avx
  else
    set +avx
    err "Could not load the trusted local .env; check its shell syntax."
  fi
  set -euo pipefail
fi

# This script has no sandbox/mock mode, and must never select production for you.
if [[ "${THINGSPACE_ENVIRONMENT:-}" != PRODUCTION ]]; then
  err "This legacy script supports live production only. Explicitly set THINGSPACE_ENVIRONMENT=PRODUCTION in the environment or a trusted local .env."
fi

require() {
  local name="$1" value
  value="${!name:-}"
  [[ -n "${value//[[:space:]]/}" ]] || err "$name is unset or empty; supply it through the environment or a trusted local .env."
  case "$value" in
    REPLACE_ME|your_client_id|your_client_secret|your_vz_m2m_token|your_account_name|your_db_host|your_db_port|your_db_user|your_db_password|placeholder)
      err "$name contains a placeholder; supply a real value." ;;
  esac
}

for name in DB_HOST DB_PORT DB_USER DB_PASSWORD \
  THINGSPACE_OAUTH_CLIENT_ID THINGSPACE_OAUTH_CLIENT_SECRET \
  THINGSPACE_VZ_M2M_TOKEN THINGSPACE_ACCOUNT_NAME; do
  require "$name"
done
if [[ ! "$DB_PORT" =~ ^[0-9]{1,5}$ ]]; then
  err "DB_PORT must be an integer from 1 to 65535."
fi
if (( 10#$DB_PORT < 1 || 10#$DB_PORT > 65535 )); then
  err "DB_PORT must be an integer from 1 to 65535."
fi

verify_runnable_jar() {
  local manifest line
  command -v unzip >/dev/null 2>&1 || err "Run requires unzip to verify the JAR manifest before starting Java."
  if ! manifest="$(unzip -p "$JAR" META-INF/MANIFEST.MF 2>/dev/null)"; then
    err "The selected JAR is invalid or has no readable manifest."
  fi
  # Only the main manifest section can declare the java -jar entry point.
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ -n "$line" ]] || break
    if [[ "$line" =~ ^[Mm][Aa][Ii][Nn]-[Cc][Ll][Aa][Ss][Ss]:[[:blank:]]+[^[:space:]] ]]; then
      return 0
    fi
  done <<< "$manifest"
  err "The selected JAR has no Main-Class entry point and cannot be started with java -jar."
}

do_build() {
  local maven_bin="$PROJECT_DIR/.deploy-tools/apache-maven-3.9.9/bin/mvn"
  local m2_home="$PROJECT_DIR/.m2"
  [[ -x "$maven_bin" ]] || err "Local Maven 3.9.9 is missing from .deploy-tools/. Restore that tool and populate .m2/repository/ before an offline build."
  printf 'Building offline with tests enabled; the local Maven cache must already be populated.\n'
  MAVEN_USER_HOME="$m2_home" "$maven_bin" -o -q -B "-Dmaven.repo.local=$m2_home/repository" clean package
  select_jar
  printf 'Packaging produced one order-server JAR.\n'
}

do_run() {
  select_jar
  command -v java >/dev/null 2>&1 || err "Java is required to run the order-server JAR."
  verify_runnable_jar
  if command -v pg_isready >/dev/null 2>&1; then
    pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" >/dev/null 2>&1 || err "Postgres is not reachable using the configured connection settings."
    printf 'Postgres readiness check passed.\n'
  fi
  printf 'Starting the Java ThingSpace order server in PRODUCTION.\n'
  exec java -jar "$JAR"
}

case "$ACTION" in
  build) do_build ;;
  run)   do_run ;;
  all)   do_build; do_run ;;
esac
