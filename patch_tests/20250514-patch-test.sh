#!/usr/bin/env bash

# dunno why this was needed
AUTH_HEADER="Ocp-Apim-Subscription-Key"
# AUTH_HEADER="x-litellm-api-key"

DEBUG=${DEBUG:-false}
if [[ $DEBUG == true ]]; then
  set -x
fi

if [[ -z "${LITELLM_API_URL:-}" ]]; then
  echo "LITELLM_API_URL is not set. Please set it to the Litellm API URL."
  exit 1
fi

if [[ -z "${LITELLM_MASTER_KEY:-}" ]]; then
  echo "LITELLM_MASTER_KEY is not set. Please set it to your Litellm API key."
  exit 1
else
    echo "Using Litellm Master key: ${LITELLM_MASTER_KEY}"
fi

if [[ -z "${TEAM_ID:-}" ]]; then
  echo "TEAM_ID is not set. Please set it to the Litellm team ID."
  exit 1
else
    echo "Using Litellm Team ID: ${TEAM_ID}"
fi

if [[ -z "${USER_ID:-}" ]]; then
  echo "USER_ID is not set. Please set it to the Litellm user ID."
  exit 1
else
    echo "Using Litellm User ID: ${USER_ID}"
fi

# check if litellm is running on port 4000
if ! nc -z localhost 4000; then
  echo "Litellm is not running on port 4000. Please start it before running the tests."
  exit 1
fi


# Test LiteLLM API authentication works
function test_success_auth() {
  RAW_CURL_OUTPUT=$( \
    curl -s -o /dev/null -X GET -w "%{http_code}" \
    -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
    "${LITELLM_API_URL}/credentials" \
  )
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Error: curl command failed with exit code $RET" > /dev/stderr
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
    return 1
  fi

  if [[ $DEBUG == true ]]; then
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
  fi
  echo $RAW_CURL_OUTPUT | grep -q "200" || return 1 && return 0
}

## Check if a team exists
function test_does_team_exist() {
  _TEAM_ID=$1
  shift

  RAW_CURL_OUTPUT=$( \
    curl -s \
    -X GET \
    -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
    "${LITELLM_API_URL}/team/list" \
  )
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Error: curl command failed with exit code $RET" > /dev/stderr
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
    return 1
  fi

  if [[ $DEBUG == true ]]; then
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
  fi

  echo "$RAW_CURL_OUTPUT" | jq -e \
    --arg tid "$_TEAM_ID" \
    '.[] |  select(.team_id == $tid)' 2>&1 > /dev/null || return 1 && return 0
}

function list_teams() {
  RAW_CURL_OUTPUT=$( \
    curl -s \
    -X GET \
    -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
    "${LITELLM_API_URL}/team/list" \
  )
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Error: curl command failed with exit code $RET" > /dev/stderr
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
    return 1
  fi
  if [[ $DEBUG == true ]]; then
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
  fi
  echo "$RAW_CURL_OUTPUT" | jq -e
}

# Create a team
function create_team() {
  _TEAM_ID=$1
  shift

  RAW_CURL_OUTPUT=$( \
    curl -s -X POST  \
    -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
    -H 'Content-Type: application/json' \
    -d "{
        \"team_alias\": \"$_TEAM_ID\",
        \"team_id\": \"$_TEAM_ID\"
    }" \
    "${LITELLM_API_URL}/team/new"
  )
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Error: curl command failed with exit code $RET" > /dev/stderr
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
    return 1
  fi
  if [[ $DEBUG == true ]]; then
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
  fi

  echo $RAW_CURL_OUTPUT | jq -e \
    --arg tid team1 \
    'select(.team_id == $tid)' 2>&1 > /dev/null || return 1 && return 0
}

# Delete a team
function delete_team() {
  _TEAM_ID=$1
  shift

  RAW_CURL_OUTPUT=$( \
    curl -s -X POST \
    -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
    -H 'Content-Type: application/json' \
    -d "{\"team_ids\": [\"${_TEAM_ID}\"]}" \
    "${LITELLM_API_URL}/team/delete" \
  )
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Error: curl command failed with exit code $RET" > /dev/stderr
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
    return 1
  fi
  if [[ $DEBUG == true ]]; then
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
  fi

  echo $RAW_CURL_OUTPUT \
    | jq -e '. == 1' 2>&1 > /dev/null || return 1 && return 0
}

# Create if a user exists
function test_does_user_exist() {
  _USER_ID=$1
  shift

  RAW_CURL_OUTPUT=$( \
    curl -s \
      -X GET \
      -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
      "${LITELLM_API_URL}/user/list" \
  )
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Error: curl command failed with exit code $RET" > /dev/stderr
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
    return 1
  fi
  if [[ $DEBUG == true ]]; then
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
  fi

  echo $RAW_CURL_OUTPUT | jq -e \
    --arg uid "$_USER_ID" \
    '.users[] | select(.user_id == $uid)' 2>&1 > /dev/null || return 1 && return 0
}

# Create a user
function create_user() {
  _USER_ID=$1
  shift

  RAW_CURL_OUTPUT=$( \
    curl -s -X POST \
    -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
    -H 'Content-Type: application/json' \
    -d "{\"user_id\": \"${_USER_ID}\", \"user_email\": \"${_USER_ID}\", \"auto_create_key\": false }" \
    "${LITELLM_API_URL}/user/new" \
  )
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Error: curl command failed with exit code $RET" > /dev/stderr
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
    return 1
  fi
  if [[ $DEBUG == true ]]; then
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
  fi

  echo $RAW_CURL_OUTPUT | jq -e \
    --arg uid "$_USER_ID" \
    'select(.user_id == $uid)' 2>&1 > /dev/null || return 1 && return 0
}

# Delete a user
function delete_user() {
  _USER_ID=$1
  shift

  RAW_CURL_OUTPUT=$( \
    curl -s -X POST \
    -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
    -H 'Content-Type: application/json' \
    -d "{\"user_ids\": [\"${_USER_ID}\"]}" \
    "${LITELLM_API_URL}/user/delete" \
  )
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Error: curl command failed with exit code $RET" > /dev/stderr
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
    return 1
  fi
  if [[ $DEBUG == true ]]; then
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
  fi
  echo $RAW_CURL_OUTPUT | jq -e \
  '. == 1' 2>&1 > /dev/null || return 1 && return 0
}

# Check if a user exists in a team
function test_user_exist_in_team() {
  _USER_ID=$1
  _TEAM_ID=$2
  shift 2

  RAW_CURL_OUTPUT=$( \
    curl -s -X GET \
      -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
      "${LITELLM_API_URL}/team/list" \
  )
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Error: curl command failed with exit code $RET" > /dev/stderr
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
    return 1
  fi
  if [[ $DEBUG == true ]]; then
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
  fi
  # Checks if the user exists in the team
  echo $RAW_CURL_OUTPUT | jq -e \
    --arg uid "$_USER_ID" \
    --arg tid "$_TEAM_ID" \
    '.[] | select(.team_id == $tid) | .members_with_roles[] | select(.user_id == $uid)' \
    2>&1 > /dev/null && return 0 || return 1
}

# Add a user to a team
function add_user_to_team() {
  _USER_ID=$1
  _TEAM_ID=$2
  shift 2

  RAW_CURL_OUTPUT=$( \
    curl -s -X POST \
      -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
      -H 'Content-Type: application/json' \
      -d "{
          \"team_id\": \"${_TEAM_ID}\",
          \"member\": [
              {
                  \"role\": \"user\",
                  \"user_id\": \"${_USER_ID}\"
              }
          ]
      }" \
      "${LITELLM_API_URL}/team/member_add" \
  )
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Error: curl command failed with exit code $RET" > /dev/stderr
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
    return 1
  fi
  if [[ $DEBUG == true ]]; then
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
  fi
  # verifies returned results
  echo $RAW_CURL_OUTPUT | jq -e \
    --arg uid "$_USER_ID" \
    --arg tid "$_TEAM_ID" \
    'select(.team_id == $tid) | .members_with_roles[] | select(.user_id == $uid)' \
    2>&1 > /dev/null || return 1 && return 0
}

# Delete a user from a team
function delete_user_from_team() {
  _USER_ID=$1
  _TEAM_ID=$2
  shift 2

  RAW_CURL_OUTPUT=$( \
    curl -s -X POST \
      -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
      -H 'Content-Type: application/json' \
      -d "{
          \"team_id\": \"${_TEAM_ID}\",
          \"user_id\": \"${_USER_ID}\"
      }" \
      "${LITELLM_API_URL}/team/member_delete" \
  )
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Error: curl command failed with exit code $RET" > /dev/stderr
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
    return 1
  fi
  if [[ $DEBUG == true ]]; then
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
  fi
  # verifies returned results
  echo $RAW_CURL_OUTPUT | jq -e \
    --arg uid "$_USER_ID" \
    --arg tid "$_TEAM_ID" \
    'select(.team_id == $tid)
     | .members_with_roles[]
     | select(.user_id == $uid)' 2>&1 > /dev/null || return 0 && return 1
}


# Delete a user from a team (without checking if the user exists)
function delete_team_membership() {
  _USER_ID=$1
  _TEAM_ID=$2
  shift 2
  curl -s -X POST \
    -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
    -H 'Content-Type: application/json' \
    -d "{
        \"team_id\": \"${_TEAM_ID}\",
        \"user_id\": \"${_USER_ID}\"
    }" \
    "${LITELLM_API_URL}/team/member_delete" \
    | jq -e \
    --arg uid "$_USER_ID" \
    --arg tid "$_TEAM_ID" \
    'select(.team_id == $tid) | .members_with_roles[] | select(.user_id == $uid)' 2>&1 > /dev/null || return 0 && return 1
}


# list all budget ids
function list_budget_ids() {

  RAW_CURL_OUTPUT=$( \
    curl -s -X GET \
      -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
      "${LITELLM_API_URL}/budget/list" \
  )
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Error: curl command failed with exit code $RET" > /dev/stderr
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
    return 1
  fi
  if [[ $DEBUG == true ]]; then
    echo "$RAW_CURL_OUTPUT" > /dev/stderr
  else
    echo "$RAW_CURL_OUTPUT" | jq -r '.[].budget_id'
  fi
}

# check if a user budget exists in team
function test_does_budget_exist__MAYBE() {
  _USER_ID=$1
  _TEAM_ID=$2
  shift 2

  # 1st get team list with user
  curl -s -X GET \
    -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
    -H 'Content-Type: application/json' \
    "${LITELLM_API_URL}/team/list" \
  | jq -e \
    --arg uid "$_USER_ID" \
    --arg tid "$_TEAM_ID" \
    '.[] | select(.team_id == $tid) | .team_memberships[] | select(.user_id == $uid)' \
  2>&1 > /dev/null && return 0 || return 1
}


# get_team_memberships - returns list of all memberships for a team
function get_team_memberships() {
  _TEAM_ID=$1
  shift 1
  curl -s -X GET \
    -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
    "${LITELLM_API_URL}/team/list" \
  | jq -e \
    --arg uid "$_USER_ID" \
    --arg tid "$_TEAM_ID" \
    '.[] | select(.team_id == $tid) | .team_memberships[]'
}


function get_budget_id_for_member() {
  _USER_ID=$1
  _TEAM_ID=$2
  shift 2

  RAW_CURL_OUTPUT=$( \
    curl -s -X GET \
      -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
      "${LITELLM_API_URL}/team/list"
  )
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Error: curl command failed with exit code $RET" > /dev/stderr
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
    return 1
  fi
  if [[ $DEBUG == true ]]; then
    echo "$CURL_OUTPUT" > /dev/stderr
  fi

  mapfile -t TMPARRAY <<< $(echo "$RAW_CURL_OUTPUT" | jq -r \
  --arg uid "$_USER_ID" \
  --arg tid "$_TEAM_ID" \
  '.[] | select(.team_id == $tid) | .team_memberships[] | select(.user_id == $uid) | .budget_id')

  echo ${TMPARRAY[@]}
}

# Delete a budget for a user on a team (BAD BECAUSE IT DOESN'T SUPPORT NULL BUDGET FOR TEAM MEMBER YET)
function delete_budget() {
  _BUDGET_ID=$1
  _USER_ID=$2
  _TEAM_ID=$3
  shift 3

  RAW_CURL_OUTPUT1=$( \
    curl -s -X POST \
      -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
      -H 'Content-Type: application/json' \
      -d "{
          \"id\": \"${_BUDGET_ID}\"
          }" \
      "${LITELLM_API_URL}/budget/delete" \
  )
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Error: curl command failed with exit code $RET" > /dev/stderr
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT1" > /dev/stderr
    return 1
  fi
  if [[ $DEBUG == true ]]; then
    echo "$RAW_CURL_OUTPUT1" > /dev/stderr
  fi

  ## @TODO: VERIFY THAT THIS IS A FIX AFTER MEMBER DEL bug?
  # RAW_CURL_OUTPUT2=$(curl -s -X POST "$LITELLM_API_URL/team/member_update" \
  #    -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
  #    -H "Content-Type: application/json" \
  #    -d "{
  #          \"team_id\": \"$_TEAM_ID\",
  #          \"user_id\": \"$_USER_ID\"
  #        }" \
  # )
  # RET=$?
  # if [[ $RET -ne 0 ]]; then
  #   echo "Error: curl command failed with exit code $RET" > /dev/stderr
  #   echo "CURL_OUTPUT: $RAW_CURL_OUTPUT2" > /dev/stderr
  #   return 1
  # fi
  # if [[ $DEBUG == true ]]; then
  #   echo "Wiping max_budget_in_team?" > /dev/stderr
  #   echo "$RAW_CURL_OUTPUT2" > /dev/stderr
  # fi

  echo $RAW_CURL_OUTPUT1 | jq -e \
    --arg bid ${_BUDGET_ID} \
    'select(.budget_id == $bid)' 2>&1 > /dev/null || return 1 && return 0
}

# Create a member budget for team / user
function update_team_member_budget() {
  _USER_ID=$1
  _TEAM_ID=$2
  _MAX_BUDGET_IN_TEAM=$3
  shift 3

  RAW_CURL_OUTPUT=$( \
    curl -s -X POST \
    -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
    -H 'Content-Type: application/json' \
    -d "{
        \"team_id\": \"${_TEAM_ID}\",
        \"user_id\": \"${_USER_ID}\",
        \"max_budget_in_team\": \"${_MAX_BUDGET_IN_TEAM}\"
    }" \
    "${LITELLM_API_URL}/team/member_update" \
  )
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Error: curl command failed with exit code $RET" > /dev/stderr
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
    return 1
  fi
  if [[ $DEBUG == true ]]; then
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
  fi
  # verifies returned results
  echo $RAW_CURL_OUTPUT | jq -e \
    --arg uid user1@email.com \
    --arg tid team1 'select(.user_id == $uid) and select(.team_id == $tid)' \
    2>&1 > /dev/null || return 0 && return 1
}

function get_team_member_budget() {
  _USER_ID=$1
  _TEAM_ID=$2
  shift 2

  RAW_CURL_OUTPUT=$( \
    curl -s -X GET \
      -H "${AUTH_HEADER}: ${LITELLM_MASTER_KEY}" \
      "${LITELLM_API_URL}/team/list" \
  )
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Error: curl command failed with exit code $RET" > /dev/stderr
    echo "CURL_OUTPUT: $RAW_CURL_OUTPUT" > /dev/stderr
    return 1
  fi
  if [[ $DEBUG == true ]]; then
    echo "$CURL_OUTPUT" > /dev/stderr
  fi

  mapfile -t TMPARRAY <<< $(echo "$RAW_CURL_OUTPUT" | jq -r \
    --arg uid "$_USER_ID" \
    --arg tid "$_TEAM_ID" \
    '.[] | select(.team_id == $tid) | .team_memberships[] | select(.user_id == $uid) | .litellm_budget_table.max_budget')

  echo ${TMPARRAY[@]}
}

# Delete and recreate the team
function setup_team() {
  _TEAM_ID=$1
  shift

  if test_does_team_exist $_TEAM_ID; then
    echo "Team, $_TEAM_ID, exists!"
    echo "Deleting team..."
    delete_team $_TEAM_ID
    sleep 2
    if test_does_team_exist $_TEAM_ID; then
      echo "Failed to delete team.."
      exit 1
    fi
  fi

  echo "creating a team..."
  if create_team $_TEAM_ID; then
    sleep 2
    echo "Team, $_TEAM_ID, created!"
    if test_does_team_exist; then
      echo "Failed to create team.."
      exit 1
    fi
  else
    echo "failed to create team..."
    exit 1
  fi
}

# Delete and recreate the test user
function setup_user() {
  _USER_ID=$1
  shift
  if test_does_user_exist $_USER_ID; then
    echo "User, $_USER_ID, exists!"
    echo "Deleting user..."
    delete_user $_USER_ID
    sleep 2
    if test_does_user_exist $_USER_ID; then
      echo "Failed to delete user.."
      exit 1
    fi
  fi

  echo "creating a user..."
  if create_user $_USER_ID; then
    echo "User, $_USER_ID, created!"
    if test_does_user_exist; then
      echo "Failed to create user.."
      exit 1
    fi
  else
    echo "failed to create user..."
    exit 1
  fi
}

# Delete membership and add user to team
function setup_member() {
  _USER_ID=$1
  _TEAM_ID=$2
  shift 2

  if test_user_exist_in_team $_USER_ID $_TEAM_ID; then
    echo "User, $_USER_ID, is a member of team, $_TEAM_ID!"
    echo "Deleting user from team..."
    delete_user_from_team $_USER_ID $_TEAM_ID
  fi
  echo "Adding user to a team..."
  add_user_to_team $_USER_ID $_TEAM_ID
  sleep 2
  if test_user_exist_in_team $_USER_ID $_TEAM_ID; then
    echo "User, $_USER_ID, added to team, $_TEAM_ID!"
  else
    echo "Failed to add user to team.."
    exit 1
  fi
}

function delete_membership_budget() {
  _USER_ID=$1
  _TEAM_ID=$2
  shift 2

  BUDGET_ID=$(get_budget_id_for_member $_USER_ID $_TEAM_ID)
  if [[ -n ${BUDGET_ID:-} ]]; then
    echo "BUDGET_ID: $BUDGET_ID"
    echo "User, $_USER_ID, already has a budget in team, $_TEAM_ID!"
    echo "Deleting team member's budget..."
    delete_budget $BUDGET_ID
    sleep 2
    BUDGET_ID=$(get_budget_id_for_member $_USER_ID $_TEAM_ID)
    if [[ -n ${BUDGET_ID:-} ]]; then
      echo "Failed to delete budget.."
      exit 1
    fi
  fi
}

function test_membership_budget() {
  _USER_ID=$1
  _TEAM_ID=$2
  shift 2

  # remove team membership's budget
  delete_membership_budget $_USER_ID $_TEAM_ID

  echo "Creating budget for user, $_USER_ID, in team, $_TEAM_ID..."
  update_team_member_budget $USER_ID $TEAM_ID 1
  MAX_BUDGET=$(get_team_member_budget $USER_ID $TEAM_ID)
  if [[ -z ${MAX_BUDGET:-} ]]; then
    echo "Failed to create budget for user, $_USER_ID, in team, $_TEAM_ID!"
    exit 1
  elif [[ $MAX_BUDGET != "1.0" ]]; then
    echo "Value did not match 1.0, got $MAX_BUDGET for user, $_USER_ID, in team, $_TEAM_ID!"
    exit 1
  else
    echo "Max Budget of $MAX_BUDGET for user, $_USER_ID, in team, $_TEAM_ID, created successfully!"
  fi

  BUDGET_ID=$(get_budget_id_for_member $_USER_ID $_TEAM_ID)
  echo "New budget: $BUDGET_ID"
  # 2nd try to re-update the budget
  echo "Updating budget for user, $_USER_ID, in team, $_TEAM_ID..."
  update_team_member_budget $USER_ID $TEAM_ID 99
  MAX_BUDGET=$(get_team_member_budget $USER_ID $TEAM_ID)
  if [[ -z ${MAX_BUDGET:-} ]]; then
    echo "Failed to create budget for user, $_USER_ID, in team, $_TEAM_ID!"
    exit 1
  elif [[ $MAX_BUDGET != "99.0" ]]; then
    echo "Value did not match 99.0, got $MAX_BUDGET for user, $_USER_ID, in team, $_TEAM_ID!"
    exit 1
  else
    echo "Max Budget of $MAX_BUDGET for user, $_USER_ID, in team, $_TEAM_ID, created successfully!"
  fi

  # 3rd try to re-re-update the budget
  echo "Updating budget for user, $_USER_ID, in team, $_TEAM_ID..."
  update_team_member_budget $USER_ID $TEAM_ID 1000
  MAX_BUDGET=$(get_team_member_budget $USER_ID $TEAM_ID)
  if [[ -z ${MAX_BUDGET:-} ]]; then
    echo "Failed to create budget for user, $_USER_ID, in team, $_TEAM_ID!"
    exit 1
  elif [[ $MAX_BUDGET != "1000.0" ]]; then
    echo "Value did not match 1000.0, got $MAX_BUDGET for user, $_USER_ID, in team, $_TEAM_ID!"
    exit 1
  else
    echo "Max Budget of $MAX_BUDGET for user, $_USER_ID, in team, $_TEAM_ID, created successfully!"
  fi

  # 4th, make sure there is only one budget
  BUDGET_COUNT=$(get_team_memberships $_TEAM_ID | jq -e \
    --arg uid "$USER_ID" \
    'select(.user_id == $uid) | .budget_id' | wc -l)
  if [[ $BUDGET_COUNT -gt 1 ]]; then
    echo "User, $_USER_ID, has multiple budgets in team, $_TEAM_ID!"
    exit 1
  elif [[ $BUDGET_COUNT -eq 0 ]]; then
    echo "User, $_USER_ID, does not have a budget in team, $_TEAM_ID!"
    exit 1
  else
    echo "User, $_USER_ID, has a single budget in team, $_TEAM_ID!"
  fi

  # show budgets
  echo "Listing all budgets..."
  BUDGET_IDS=$(list_budget_ids)
  echo $BUDGET_IDS
}




if test_success_auth; then
  echo "Authenticated successfully!"
else
  echo "Authentication failed. Please check your API credentials."
  exit 1
fi

list_teams
# test_does_team_exist $TEAM_ID

setup_team $TEAM_ID
setup_user $USER_ID
setup_member $USER_ID $TEAM_ID

test_membership_budget $USER_ID $TEAM_ID
