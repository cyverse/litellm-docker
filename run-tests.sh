#!/usr/bin/env bash

# This script is used to run the patch tests for the project.
set -euo pipefail

# Make arrays empty if no input
shopt -s nullglob

PRJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PATCH_TESTS_DIR="${PATCH_TESTS_DIR:-${PRJ_DIR}/patch_tests}"
export LITELLM_API_URL="${LITELLM_API_URL:-http://localhost:4000}"
export LITELLM_MASTER_KEY="${LITELLM_MASTER_KEY:-sk-master-key}"

export TEAM_ID="team1"
export USER_ID="user1@email.com"

# Check if the required environment variable is set
if [[ -z "${PATCH_TESTS_DIR:-}" ]]; then
  echo "Error: PATCH_TESTS_DIR environment variable is not set."
  exit 1
fi

# Check if the directory exists
if [[ ! -d "$PATCH_TESTS_DIR" ]]; then
  echo "Error: PATCH_TESTS_DIR, ${PATCH_TESTS_DIR}, does not point to a valid directory."
  exit 1
fi

# Change to the patch tests directory
cd "$PATCH_TESTS_DIR" || exit 1
# Run the patch tests
echo "Running patch tests in $PATCH_TESTS_DIR..."
# Enable nullglob so that no matches yield an empty array
shopt -s nullglob
test_files=( *.sh )
if [[ ${#test_files[@]} -eq 0 ]]; then
  echo "No patch tests found in $PATCH_TESTS_DIR."
  exit 0
fi

for test_file in "${test_files[@]}"; do
  echo "Running test: $test_file"
  bash "$test_file"
  if [[ $? -ne 0 ]]; then
    echo "Test $test_file failed."
    exit 1
  fi
done
echo "All patch tests passed successfully."