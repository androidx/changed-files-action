#!/bin/bash
# Find changed files in a build either via pull request API or compare API
set -x
function set_output_files {
    local JSON=$1
    local OUTPUT_VAR=$2
    local EXCLUDE_STATUS=$3
    if [[ -z $JSON || -z $OUTPUT_VAR || -z EXCLUDE_STATUS ]]
    then
        echo "missing some parameters: $JSON $OUTPUT_VAR $EXCLUDE_STATUS"
        exit 1
    fi
    FILES=$(echo $JSON | jq --arg excludedStatus $EXCLUDED_STATUS -r '.[] | select(.status != "$excludedStatus") | .filename' | tr '\r\n' ' ')
    echo "::set-output name=${OUTPUT_VAR}::$FILES"
}

cat $GITHUB_EVENT_PATH
COMPARE=$(jq '.compare' $GITHUB_EVENT_PATH)
PR=$(jq -r '.pull_request._links.self.href' $GITHUB_EVENT_PATH)
echo "-----"
echo "compare: |$COMPARE|"
echo "PR: |$PR|"
echo "------"

if [[ -z "${GITHUB_TOKEN}" ]]; then
  TOKEN_HEADER=""
else
  TOKEN_HEADER="Authorization: token $GITHUB_TOKEN"
fi

FORMAT_HEADER="Accept: application/vnd.github.v3+json"

if [[ $COMPARE != null ]]
then
    # compare might be a compare url or a commit url (single commit case)
    if [[ $COMPARE == *"/commit/"* ]]
    then
        COMPARE_API=$(echo $COMPARE | sed 's/github.com\//api.github.com\/repos\//g'| sed 's/commit/commits/'| sed 's/"//g')
    elif  [[ $COMPARE == *"/compare/"* ]]
    then
        #compare url is set, using it from the API
        COMPARE_API=$(echo $COMPARE | sed 's/github.com\//api.github.com\/repos\//g'| sed 's/"//g')
    else
        echo "unknown compare format: $COMPARE"
        exit 1
    fi
    # TODO paginate to support more than 100 files
    COMPARE_RESPONSE=$(curl -H $FORMAT_HEADER -H "$TOKEN_HEADER" "$COMPARE_API?per_page=100")
    FILES_JSON=$(echo $COMPARE_RESPONSE | jq -r '.files')
elif [[ $PR != null ]]
then
    #this is a PR, using its files API
    PR_FILES_API="$PR/files"
    # TODO paginate to support more than 100 files
    FILES_JSON=$(curl -H $FORMAT_HEADER -H "$TOKEN_HEADER" "$PR_FILES_API?per_page=100")
else
    echo "CANNOT FIND CHANGED FILES"
    exit 1
fi

set_output_files "$FILES_JSON" "files" "removed"
set_output_files "$FILES_JSON" "files_including_removals" ""
