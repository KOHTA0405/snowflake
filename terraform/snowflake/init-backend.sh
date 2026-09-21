#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Read only the account name assignment. Sourcing .env would also load credentials.
if [[ -f .env ]]; then
  account_name=$(awk '
    /^[[:space:]]*(export[[:space:]]+)?TF_VAR_SNOWFLAKE_ACCOUNT[[:space:]]*=/ {
      sub(/^[[:space:]]*(export[[:space:]]+)?TF_VAR_SNOWFLAKE_ACCOUNT[[:space:]]*=[[:space:]]*/, "")
      print
      exit
    }
  ' .env)
else
  account_name=${TF_VAR_SNOWFLAKE_ACCOUNT:-}
fi

account_name=${account_name%%#*}
account_name="${account_name#"${account_name%%[![:space:]]*}"}"
account_name="${account_name%"${account_name##*[![:space:]]}"}"
account_name=${account_name#\"}
account_name=${account_name%\"}
account_name=${account_name#\'}
account_name=${account_name%\'}

if [[ ! $account_name =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "Set TF_VAR_SNOWFLAKE_ACCOUNT in .env (or the environment) to an account name containing only letters, digits, _ or -." >&2
  exit 1
fi

terraform init -reconfigure -backend-config="key=snowflake/${account_name}/tfstate"
