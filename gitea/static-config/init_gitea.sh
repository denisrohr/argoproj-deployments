#!/bin/bash

removequote(){
	echo $1 | awk '{gsub(/\"/,"")};1'
}

normalizenewlines(){
	echo $1 | tr -d '\r'
}

mirrorrepo () {
   curl -s -X POST "http://localhost:3000/api/v1/repos/migrate" -H "accept: application/json" -H "Authorization: token $GITEA_API_TOKEN" -H "Content-Type: application/json" -d "{\"clone_addr\":\"$REMOTE_URL\", \"uid\":$USER_ID, \"repo_name\":\"$LOCAL_REPO\", \"mirror\":true}"
   curl -s -X POST "http://localhost:3000/api/v1/repos/$GITEA_USER/$LOCAL_REPO/keys" -H "accept: application/json" -H "Authorization: token $GITEA_API_TOKEN" -H "Content-Type: application/json" -d "{\"title\":\"argocd\", \"read_only\":true, \"key\":\"$DEPLOY_KEY\"}"
}

export PATH=/tools:$PATH
export GITEA_URL=http://127.0.0.1:3000
export GITEA_USER=mirror
export PASSWORD=admin
export HTTPAUTH=$(printf "$GITEA_USER:$PASSWORD" | base64)
while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' $GITEA_URL)" != "200" ]]; do sleep 5; done;
gitea migrate
gitea admin create-user --name $GITEA_USER --password $PASSWORD --admin --email admin@local.local --must-change-password=false
export GITEA_API_TOKEN=$(curl -s -X POST "http://localhost:3000/api/v1/users/$GITEA_USER/tokens" -H "accept: application/json" -H "Authorization: Basic $HTTPAUTH" -H "Content-Type: application/json" -d "{ \"name\": \"drone\"}" | jq -r '.sha1')
export USER_ID=$(curl -s -X GET "http://localhost:3000/api/v1/users/$GITEA_USER" -H "accept: application/json" -H "Authorization: Basic $HTTPAUTH" -H "Content-Type: application/json" | jq -r '.id')

tr -d '\r' < /data/mirrors/mirrors.csv > /tmp/mirrors.csv

while IFS=, read -r col1 col2 col3 || [ "$col1" ]
do
    export REMOTE_URL=$(removequote $(normalizenewlines $col1))
	export LOCAL_REPO=$(removequote $(normalizenewlines $col2))
	export DEPLOY_KEY=$(removequote $(normalizenewlines $col3))
    mirrorrepo
done < /tmp/mirrors.csv

