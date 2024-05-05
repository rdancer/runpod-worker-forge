#!/bin/bash
# reboot.sh -- reboot this worker instance by terminating it through RunPod's GraphQL API.

set -x



# API endpoint for RunPod GraphQL
api_endpoint="https://api.runpod.io/graphql"

# API key for authorization
# we get this from the environment
#RUNPOD_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# This is the ID under which the API identifies the worker instance
# we get this from the environment
#RUNPOD_POD_ID=xxxxxxxxxxxxxx

url="${api_endpoint}?api_key=${api_key}"

terminate() {
  # Define the JSON payload for the GraphQL API call.
  json='
  {
    "operationName": "terminatePod",
    "variables": {
      "input": {
        "podId": "'${1-$RUNPOD_POD_ID}'"
      }
    },
    "query": "mutation terminatePod($input: PodTerminateInput!) { podTerminate(input: $input) }"
  }
  '
  curl \
      --silent \
      --show-error \
      --request POST \
      --header 'content-type: application/json' \
      --url "https://api.runpod.io/graphql?api_key=${RUNPOD_API_KEY}" \
      --data "$json" \
  | jq .
}

print_info() {
  # from the docs -- see https://docs.runpod.io/sdks/graphql/manage-endpoints (accessed 2024-05-03)
  curl \
      --silent \
      --show-error \
      --request POST \
      --header 'content-type: application/json' \
      --url "https://api.runpod.io/graphql?api_key=${RUNPOD_API_KEY}" \
      --data '{"query": "query Endpoints { myself { endpoints { gpuIds id idleTimeout locations name networkVolumeId pods { desiredStatus } scalerType scalerValue templateId workersMax workersMin } serverlessDiscount { discountFactor type expirationDate } } }"}' \
  | jq ".data.myself.endpoints[] | select(.id == \"${1-$RUNPOD_POD_ID}\")"
}

if [ x$1 = x"--terminate-dev" ]; then
  echo "Terminating all dev workers, so that they get recreated"
  dev_name=forge-dev-0
  curl \
     --silent \
     --show-error \
     --request POST \
     --header 'content-type: application/json' \
     --url "https://api.runpod.io/graphql?api_key=${RUNPOD_API_KEY}" \
     --data '{"query": "query Endpoints { myself { endpoints { gpuIds id idleTimeout locations name networkVolumeId pods { desiredStatus } scalerType scalerValue templateId workersMax workersMin } serverlessDiscount { discountFactor type expirationDate } } }"}' \
  | jq -r ".data.myself.endpoints[] | select(.name == \"$dev_name\").id" \
  | while read worker_id; do
    echo "Terminating worker $worker_id"
    print_info $worker_id
    echo --------------------------------------------------------------------------
    terminate $worker_id
  done
else
  echo "Terminating worker $RUNPOD_POD_ID"
  echo --------------------------------------------------------------------------
  print_info $RUNPOD_POD_ID
  terminate $RUNPOD_POD_ID
fi
