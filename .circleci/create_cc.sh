#!/bin/bash

PROJECT_KEY="CC"

run () {
  fetch_circleci_job

  JSON_STRING=$(jq -n \
	--arg project "${PROJECT_KEY}" \
  --arg summary "${CIRCLE_PROJECT_REPONAME} Deployment - ${PR_TITLE}" \
	JSON_STRING=$(jq -n \
	--arg project "${PROJECT_KEY}" \
  	--arg summary "${CIRCLE_PROJECT_REPONAME} Deployment - ${PR_TITLE}" \
	--arg desc "Based on SOP-80 https://app.qualio.com/reference/SOP-80
	
Every deployment to production with bug fix / non customer facing changes (to be governed by the above policy) requires:
A list of changes to be compiled
Risk assessment and mitigation if necessary
Team lead sign off\nLink to release PR in github

Github link:
${PULL_REQUESTS}
CircleCi link:
${CIRCLE_BUILD_URL}
CHANGE LIST GOES HERE AND IS UPDATED IN THIS TASK
${JIRA_TICKETS}
Risk / mitigation:
" \
	'{
		fields : {
			project: { 
				key: $project
			}, 
			summary: $summary,
		    description: {
				type: "doc",
				version: 1,
				content: [
					{
						type: "paragraph",
						content: [
							{
								text: $content,
								type: "text"
							}
						]
					}
				]
			},
			issuetype: {
				name: "Story"
			}
		}
	}')
  
  echo ${JSON_STRING}

  curl -d "${JSON_STRING}" -u franki10101@gmail.com:${JIRA_TOKEN} -X POST -H "Content-Type: application/json" https://ftyyeung.atlassian.net/rest/api/3/issue
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

  PR_TITLE=$(jq -r '.[0] | .title' < /tmp/pullrequests.json)

  # Parse all commits in pull requests for mentioned Jira Tickets
  IFS=$'\n'
  for url in ${PULL_REQUESTS}    
  do
    PULL_REQUEST_NUM="${url##*/}"
    OUTPUT_FILE="pr${PULL_REQUEST_NUM}-commits.json"
    fetch https://api.github.com/repos/ftyyeung/${CIRCLE_PROJECT_REPONAME}/pulls/${PULL_REQUEST_NUM}/commits /tmp/${OUTPUT_FILE}
    jq -r '.[] | .commit.message | scan("[A-Z]{2,30}-[0-9]+")' < /tmp/${OUTPUT_FILE} >> /tmp/jira-ticket.txt
  done 

  ESCAPED_URL=${JIRA_BASE_URL%/}
  ESCAPED_URL=$(echo "$ESCAPED_URL" | sed 's/\//\\\//g')
  sed -i -e "s/^/${ESCAPED_URL}\/browse\//" /tmp/jira-ticket.txt
  cat /tmp/jira-ticket.txt
  JIRA_TICKETS=$(cat /tmp/jira-ticket.txt | uniq)
}

run
