#!/bin/bash

run () {
  fetch_circleci_job
  echo "1. ${PULL_REQUESTS}"
  echo "2. ${CIRCLE_BUILD_URL}"
}

fetch () {
  URL="$1"
  OFILE="$2"
  RESP=$(curl -w "%{http_code}" -s  \
  -o "${OFILE}" \
  "${URL}")

  if [[ "$RESP" != "20"* ]]; then
    echo "Curl failed with code ${RESP}. full response below."
    cat $OFILE
    exit 1
  fi
}

fetch_circleci_job () {
  fetch https://api.github.com/repos/ftyyeung/${CIRCLE_PROJECT_REPONAME}/commits/${CIRCLE_SHA1}/pulls /tmp/pullrequests.json
  PULL_REQUESTS=$(jq -r '.[] | .html_url' < /tmp/pullrequests.json)
  IFS=$'\n'
  for url in ${PULL_REQUESTS}    
  do
    echo "$url"
    PULL_REQUEST_NUM="${url##*/}"
    fetch https://api.github.com/repos/ftyyeung/${CIRCLE_PROJECT_REPONAME}/pulls/${PULL_REQUEST_NUM}/commits /tmp/pr-${PULL_REQUEST_NUM}-commits.json
    cat /tmp/pr-${PULL_REQUEST_NUM}-commits-json
  done
}

run
