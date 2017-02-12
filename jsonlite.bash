#!/usr/bin/env bash

###############################################################################
# Copyright 2017 Justin Keller
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

set -eo pipefail; [[ $TRACE ]] && set -x

readonly VERSION="1.0.0"
export JSONLITE_DATA_DIR=${JSONLITE_DATA_DIR:="$PWD/jsonlite.data"}

jsonlite_version() {
  echo "JSONlite $VERSION"
}

jsonlite_info() {
  jsonlite_version

  if command -v json_reformat > /dev/null 2>&1; then
    echo "  set is using: json_reformat (fastest)"
  elif command -v jq > /dev/null 2>&1; then
    echo "  set is using: jq (fast)"
  else
    echo "  set is using: python -m json.tool (slow)"
  fi

  echo
  echo "Data directory path: $JSONLITE_DATA_DIR"
  echo
}

jsonlite_help() {
  echo "Usage: jsonlite command <command-specific-options>"
  echo
  cat<<EOF | column -c2 -t -s,
  set <json>, Writes a json document and returns a document id
  get <document-id>, Retrieves a json document by document id
  count, Total number of json documents in the database
  delete <document-id>, Deletes a json document by document id
  drop (--force), Drops the database
  help, Displays help
  version, Displays the current version
EOF
  echo
}

jsonlite_is_valid_uuid() {
  if [[ "$1" =~ ^[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}$ ]]; then
    return 0
  fi

  return 1
}

jsonlite_set() {
  local value="$1"

  if [[ -z "$value" && ! -t 0 ]]; then
    while read -r piped; do
      value+=$piped
    done;
  fi

  if [[ -z "$value" ]]; then
    echo "Missing required argument json document" 1>&2
    exit 4
  fi

  if [[ ! -d "$JSONLITE_DATA_DIR" ]]; then
    mkdir -p "$JSONLITE_DATA_DIR"
  fi

  local uuid
  uuid=$(uuidgen | awk '{print toupper($0)}')

  if command -v json_reformat > /dev/null 2>&1; then
    echo "$value" | json_reformat > "$JSONLITE_DATA_DIR/$uuid"
  elif command -v jq > /dev/null 2>&1; then
    # use the not-as-fast jq library if available
    echo "$value" | jq '.' > "$JSONLITE_DATA_DIR/$uuid"
  else
    # fallback to the slowest json.tool
    echo "$value" | python -m json.tool > "$JSONLITE_DATA_DIR/$uuid"
  fi

  echo "$uuid"
}

jsonlite_get() {
  local document_id="$1"
  if [[ -z "$document_id" ]]; then
    echo "Missing required argument document id" 1>&2
    exit 5
  fi

  if ! jsonlite_is_valid_uuid "$document_id"; then
    echo "Invalid argument document id" 1>&2
    exit 6
  fi

  if [[ -f "$JSONLITE_DATA_DIR/$document_id" ]]; then
    cat "$JSONLITE_DATA_DIR/$document_id"
  fi
}

jsonlite_count() {
  if [[ ! -d "$JSONLITE_DATA_DIR" ]]; then
    echo 0
    exit 0
  fi

  local count
  count=$(find "$JSONLITE_DATA_DIR" -type f | wc -l)

  # piping to xargs is a trick to trim (remove leading & trailing whitespace)
  echo "$count" | xargs
}

jsonlite_delete() {
  local document_id="$1"
  if [[ -z "$document_id" ]]; then
    echo "Missing required argument document id" 1>&2
    exit 5
  fi

  if ! jsonlite_is_valid_uuid "$document_id"; then
    echo "Invalid argument document id" 1>&2
    exit 6
  fi

  if [[ -f "$JSONLITE_DATA_DIR/$document_id" ]]; then
    rm -f "$JSONLITE_DATA_DIR/$document_id"
  fi
}

jsonlite_drop() {
  if [[ ! -d "$JSONLITE_DATA_DIR" ]]; then
    return 0
  fi

  if [[ "$1" == "--force" ]]; then
    rm -rf "$JSONLITE_DATA_DIR"
    return $?
  fi

  read -rp "Drop database '$JSONLITE_DATA_DIR'? [Y/n] " confirm
  case "$confirm" in
    Y|y|YES|yes ) rm -rf "$JSONLITE_DATA_DIR";;
    * ) exit 7;;
  esac
}

jsonlite_main() {
  local COMMAND="$1"

  if [[ -z $COMMAND ]]; then
      jsonlite_info
      jsonlite_help
      exit 0
  fi

  shift 1
  case "$COMMAND" in
    "set")
      jsonlite_set "$@"
      ;;

    "get")
      jsonlite_get "$@"
      ;;

    "count")
      jsonlite_count
      ;;

    "delete")
      jsonlite_delete "$@"
      ;;

    "drop")
      jsonlite_drop "$@"
      ;;

    "version")
      jsonlite_version
      ;;

    "help")
      jsonlite_help
      ;;

    *)
      jsonlite_help >&2
      exit 3
  esac
}

if [[ "$0" == "$BASH_SOURCE" ]]; then
  jsonlite_main "$@"
fi
