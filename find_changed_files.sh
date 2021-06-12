#!/bin/bash
# Find changed files in a build either via pull request API or compare API
echo "event path: $GITHUB_EVENT_PATH"
cat $GITHUB_EVENT_PATH
COMPARE=$(jq '.compare' $GITHUB_EVENT_PATH)
PR=$(jq -r '.pull_request._links.self.href' $GITHUB_EVENT_PATH)
echo "-----"
echo "compare: |$COMPARE|"
echo "PR: |$PR|"
echo "------"
if [[ $COMPARE != null ]]
then
    echo "compare url is set, using it from the API"
    # api.github.com/repos
    COMPARE_API=$(echo $COMPARE | sed 's/github.com\//api.github.com\/repos\//g'| sed 's/"//g')
    echo "compare API url: $COMPARE_API"
    COMPARE_RESPONSE=$(curl -H "Accept: application/vnd.github.v3+json" $COMPARE_API)
    echo "compare response: $COMPARE_RESPONSE"
    # statuses we are interested in: added, modified, renamed. basically, anything but removed
    CHANGED_FILES=$(echo $COMPARE_RESPONSE | jq -r '.files | .[] | select(.status != "removed") | .filename' | tr '\r\n' ' ')
elif [[ $PR != null ]]
then
    echo "this is a PR, using its files API"
    PR_FILES_API="$PR/files"
    PR_FILES_RESPONSE=$(curl -H "Accept: application/vnd.github.v3+json" $PR_FILES_API)
    CHANGED_FILES=$(echo $PR_FILES_RESPONSE | jq -r '.[] | select(.status != "removed") | .filename' | tr '\r\n' ' ')
else
    echo "CANNOT FIND CHANGED FILES"
    exit 1
fi

echo "changed files: $CHANGED_FILES"
echo "::set-output name=files::$CHANGED_FILES"