#!/usr/bin/env bash -ex

set -o errexit
set -o pipefail
set -o nounset

# Run a curl health check against the Grafana instance, should poll instead

attempt_counter=0
max_attempts=10
URL=http://grafana
initial_sleep=30

echo "Curling against the Grafana server"
echo "Wait $initial_sleep seconds for to boot, expecting 200"
sleep $initial_sleep
while true
do
    
    HTTP_RESPONSE=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" -X POST $URL)
    
    # extract the body
    HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed -e 's/HTTPSTATUS\:.*//g')
    # extract the status
    HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    
    
    if [ ${attempt_counter} -eq ${max_attempts} ];then
        echo "Max attempts reached"
        echo "Last reponse was code: $HTTP_STATUS and body: $HTTP_BODY"
        exit 1
    fi
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo "Grafana has come up and ready to use"
        exit 0
    else
        echo "Got $STATUS :( Not done yet..."
    fi
    
    attempt_counter=$($attempt_counter+1)
    sleep 10
done