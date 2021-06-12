#!/bin/bash
# Find changed files in a build either via pull request API or compare API
set -x
cat $GITHUB_EVENT_PATH
COMPARE=$(jq '.compare' $GITHUB_EVENT_PATH)
PR=$(jq -r '.pull_request._links.self.href' $GITHUB_EVENT_PATH)
echo "-----"
echo "compare: |$COMPARE|"
echo "PR: |$PR|"
echo "------"
if [[ $COMPARE != null ]]
then
    #compare url is set, using it from the API
    COMPARE_API=$(echo $COMPARE | sed 's/github.com\//api.github.com\/repos\//g'| sed 's/"//g')
    COMPARE_RESPONSE=$(curl -H "Accept: application/vnd.github.v3+json" $COMPARE_API)
    # statuses we are interested in: added, modified, renamed. basically, anything but removed
    CHANGED_FILES=$(echo $COMPARE_RESPONSE | jq -r '.files | .[] | select(.status != "removed") | .filename' | tr '\r\n' ' ')
elif [[ $PR != null ]]
then
    #this is a PR, using its files API
    PR_FILES_API="$PR/files"
    PR_FILES_RESPONSE=$(curl -H "Accept: application/vnd.github.v3+json" $PR_FILES_API)
    CHANGED_FILES=$(echo $PR_FILES_RESPONSE | jq -r '.[] | select(.status != "removed") | .filename' | tr '\r\n' ' ')
else
    echo "CANNOT FIND CHANGED FILES"
    exit 1
fi

echo "::set-output name=files::$CHANGED_FILES"