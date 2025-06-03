#!/usr/bin/env bash
set -euo pipefail

## Note: this depends on the litellm project being in a specific directory structure relative to this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
## PRJDIR is the directory where the Litellm project source is located
PRJDIR="$(cd "${script_dir}/../litellm" && pwd -P)"

if [[ ! -f "${script_dir}/.env" ]]; then
  echo "ERROR: Litellm-docker .env not found in ${script_dir}" > /dev/stderr
  exit 1
else
  source "${script_dir}/.env"
fi

if [[ -z "${MAIN_TAG}" ]]; then
  echo "ERROR: MAIN_TAG not set in ${script_dir}/.env" > /dev/stderr
  exit 1
fi

if [[ -z "${DKR_IMAGE_TAG}" ]]; then
  echo "ERROR: DKR_IMAGE_TAG not set in ${script_dir}/.env" > /dev/stderr
  exit 1
fi

if [[ -z "${MAIN_CO_BRANCH}" ]]; then
  echo "ERROR: MAIN_CO_BRANCH not set in ${script_dir}/.env" > /dev/stderr
  exit 1
fi

if [[ -z "${TEST_BRANCH}" ]]; then
  echo "ERROR: TEST_BRANCH not set in ${script_dir}/.env" > /dev/stderr
  exit 1
fi

if [[ -z "${PATCH_NAME}" ]]; then
  echo "ERROR: PATCH_NAME not set in ${script_dir}/.env" > /dev/stderr
  exit 1
fi

echo "        MAIN_TAG: ${MAIN_TAG}"
echo "   DKR_IMAGE_TAG: ${DKR_IMAGE_TAG}"
echo "  MAIN_CO_BRANCH: ${MAIN_CO_BRANCH}"
echo "     TEST_BRANCH: ${TEST_BRANCH}"
echo "      PATCH_NAME: ${PATCH_NAME}"

DONT_ABORT_AND_RESET=true

RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

### ORDER OF OPERATION!!!
# [litellm_tmdc_fix]          - Fixes team member update bug
# [litellm_tmu_fix]      - Fixes team member delete budget / list team bug

branches=(
  # "litellm_tmdc_fix"  # rebase this against MAIN_CO_BRANCH
  # "litellm_tmu_fix" # rebase this against litellm_team_member_update_fix

  "litellm_team_member_update_fix"
)

echo -e "${YELLOW}WARNING${NC}: This script will delete the branch ${TEST_BRANCH} if it exists and create a new one from ${MAIN_TAG}."
echo -e "${YELLOW}ALSO WARNING${NC}: this script will muck with $PRJDIR, save work and be careful!"
# Ask user to enter yes to coninue
echo -e "${RED}Are you sure you want to continue?${NC} (y/n)"
read -n 1 -s
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborting..."
  exit 1
fi
echo -e "\nContinuing..."

pushd $PRJDIR >/dev/null

# check if git MAIN_CO_BRANCH branch exists 1st
if git branch --list | grep -q "${MAIN_CO_BRANCH}"; then
  git checkout ${MAIN_CO_BRANCH}
else
  # checkout from tag
  git checkout -b ${MAIN_CO_BRANCH} ${MAIN_TAG}
fi

if git branch --list | grep -q "${TEST_BRANCH}"; then
  # delete the destination test branch if it exists
  git branch -D ${TEST_BRANCH}
fi

git checkout -b ${TEST_BRANCH} ${MAIN_CO_BRANCH} &&
  {
    for branch in "${branches[@]}"; do
      echo -e "\033[31;1;4m>>>>> MERGING BRANCH '${branch}' into '${TEST_BRANCH}' <<<<\033[0m"
      git merge --no-ff $branch -m "Merging $branch into ${TEST_BRANCH}"
      #sleep 0.25s
      sleep 2
      if [ $? -ne 0 ]; then
        git merge --abort
        echo "Error merging!"
        exit 1
      fi
    done
  }

## Now generate patch
git format-patch $MAIN_CO_BRANCH --stdout > ${script_dir}/${PATCH_NAME}.patch
if [ $? -ne 0 ]; then
  echo "Error generating patch!"
  exit 1
fi
echo "Patch generated: ${script_dir}/${PATCH_NAME}.patch"

popd >/dev/null
