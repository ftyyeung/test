#!/bin/bash

run () {
  fetch_circleci_job
  echo "1. ${PULL_REQUESTS}"
  echo "2. ${CIRCLE_BUILD_URL}"
  echo "3. ${JIRA_TICKETS}"
  
  TEMPLATE_PATH='./circleci/story_template.json'
  sed -i "s/<PROJECT>/${CIRCLE_PROJECT_REPONAME}/g" ${TEMPLATE_PATH}
  PULL_REQUESTS=$(echo "$PULL_REQUESTS" | sed 's/\//\\\//g')
  sed -i "s/<GIT_LINKS>/${PULL_REQUESTS}/g" ${TEMPLATE_PATH}
  CIRCLE_BUILD_URL=$(echo "$CIRCLE_BUILD_URL" | sed 's/\//\\\//g')
  sed -i "s/<CIRCLECI_BUILD>/${CIRCLE_BUILD_URL}/g" ${TEMPLATE_PATH}
  JIRA_TICKETS=$(echo "$JIRA_TICKETS" | sed 's/\//\\\//g')
  sed -i "s/<JIRA_LINKS>/${JIRA_TICKETS}/g" ${TEMPLATE_PATH}

  cat ${TEMPLATE_PATH}
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
  # Get the pull requests associated with this latest commit
  fetch https://api.github.com/repos/ftyyeung/${CIRCLE_PROJECT_REPONAME}/commits/${CIRCLE_SHA1}/pulls /tmp/pullrequests.json
  PULL_REQUESTS=$(jq -r '.[] | .html_url' < /tmp/pullrequests.json)

  # Get related jira ticket info from the source branch name, merge title, and body
  jq -r '.[] | .head.ref | scan("[A-Z]{2,30}-[0-9]+")' < /tmp/pullrequests.json > /tmp/jira-ticket.txt
  jq -r '.[] | .title | scan("[A-Z]{2,30}-[0-9]+")' < /tmp/pullrequests.json >> /tmp/jira-ticket.txt
  jq -r '.[] | .body | scan("[A-Z]{2,30}-[0-9]+")' < /tmp/pullrequests.json >> /tmp/jira-ticket.txt

  # Parse all commits in pull requests for mentioned Jira Tickets
  IFS=$'\n'
  for url in ${PULL_REQUESTS}    
  do
    PULL_REQUEST_NUM="${url##*/}"
    OUTPUT_FILE="pr${PULL_REQUEST_NUM}-commits.json"
    fetch https://api.github.com/repos/ftyyeung/${CIRCLE_PROJECT_REPONAME}/pulls/${PULL_REQUEST_NUM}/commits /tmp/${OUTPUT_FILE}
    jq -r '.[] | .commit.message | scan("[A-Z]{2,30}-[0-9]+")' < /tmp/${OUTPUT_FILE} >> /tmp/jira-ticket.txt
  done 

  sed -i -e "s/^/${JIRA_BASE_URL%\/}\/browse\//" /tmp/jira-ticket.txt
  JIRA_TICKETS=$(cat /tmp/jira-ticket.txt | uniq)
}

run
