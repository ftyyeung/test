#!/bin/bash -eo pipefail
: ${CIRCLE_TOKEN:?"Please provide a CircleCI API token for this orb to work!"} >&2
if [[ $(echo $CIRCLE_REPOSITORY_URL | grep github.com) ]]; then
  VCS_TYPE=github
else
  VCS_TYPE=bitbucket
fi

run () {
  verify_api_key
  fetch_circleci_job
}

verify_api_key () {
  URL="https://circleci.com/api/v2/me?circle-token=${CIRCLE_TOKEN}"
  fetch $URL /tmp/me.json
  jq -e '.login' /tmp/me.json
}

fetch () {
  URL="$1"
  OFILE="$2"
  RESP=$(curl -w "%{http_code}" -s  --user "${CIRCLE_TOKEN}:"  \
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
  cat /tmp/pullrequests.json
}

run
