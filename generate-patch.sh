#!/usr/bin/env bash
set -euo pipefail

## Note: this depends on the litellm project being in a specific directory structure relative to this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
## PRJDIR is the directory where the Litellm project source is located
PRJDIR="$(cd "${script_dir}/../litellm" && pwd -P)"

## MAIN_TAG is the tag of the Litellm project to be used as the base for the test
# MAIN_TAG='v1.67.7-stable'
MAIN_TAG='v1.67.4-stable'
## MAIN_CO_BRANCH is the branch of the Litellm project to be used as the base for the test
# MAIN_CO_BRANCH='main-v1.67.7-stable'
MAIN_CO_BRANCH="main-${MAIN_TAG}"
## TEST_BRANCH is the branch of the Litellm project to be used for mashing branches
TEST_BRANCH='franks/20250515-litellm-cyverse'

DONT_ABORT_AND_RESET=true

RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

### ORDER OF OPERATION!!!
# [litellm_team_member_update_fix]          - Fixes team member update bug
# [litellm_team_member_delete_cascade]      - Fixes team member delete budget / list team bug

branches=(
  "litellm_team_member_update_fix"  # rebase this against MAIN_CO_BRANCH
  "litellm_team_member_delete_cascade" # rebase this against litellm_team_member_update_fix
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
# v1.67.4-stable-20250515-litellm
PATCH_NAME="${MAIN_TAG}-$(date +%Y%m%d)-litellm.patch"
git format-patch $MAIN_CO_BRANCH --stdout > ${script_dir}/${PATCH_NAME}

popd >/dev/null
