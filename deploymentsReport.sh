#!/bin/sh

# This script is meant to create a report of the deployment pipelines of all gelato component.
#
# Usage:
#   API_TOKEN=<gitlab_api_token> ./deployments-report.sh
#
# For each repo it will print the following info:
# <repo name>
#   last commit: <sha_of_last_commit>
#   last successful pipeline:
#       commit: <sha_of_pipeline_commit>
#       url: <pipeline_url>
#   staging:
#       [Update message]
#       [Diff: <url_of_the_diff>]
#       commit: <sha_of_pipeline_commit_deployed_on_staging>
#       url: <pipeline_url>
#   production:
#       [Update message]
#       [Diff: <url_of_the_diff>]
#       commit: <sha_of_pipeline_commit_deployed_on_staging>
#       url: <pipeline_url>
#
# The update message will be shown if the deployed commit is not the latest successful one, in that case
# just click on the url of the latest succesful pipeline and run the related deployment job.

BASE_URL="https://gitlab.com/"
API_BASE_URL=${BASE_URL}"/api/v4/projects"
API_TOKEN="<API_token>"

declare -a projects=(
    # Insert projects here
    # Example: "username/projectName"
)

_OUTDATED_MESSAGE="This is not the latest commit, please run the last successful pipeline for this environment"

for pj in "${projects[@]}"
do
    pjEncoded=${pj//\//%2F}

    commits=$(curl --header "PRIVATE-TOKEN: $API_TOKEN" "$API_BASE_URL/$pjEncoded/repository/commits?ref_name=master&first_parent=true" 2> /dev/null | jq 'sort_by(.created_at) | reverse')
    lastCommit=$(echo $commits | tr '\r\n' ' ' | tr '\t' ' ' | jq 'first.id' | sed 's/"//g')

    pipelines=$(curl --header "PRIVATE-TOKEN: $API_TOKEN" "$API_BASE_URL/$pjEncoded/pipelines?ref=master&status=success&order_by=id&sort=desc" 2> /dev/null | tr '\r\n' ' ' | tr '\t' ' ')
    lastSuccessfulPipelineSha=$(echo $pipelines | jq 'first.sha' | sed 's/"//g')
    lastSuccessfulPipelineUrl=$(echo $pipelines | jq 'first.web_url' | sed 's/"//g')

    echo $pj
    echo "\tlast commit: "$lastCommit
    echo "\tlast successful pipeline"
    echo "\t\tcommit: "$lastSuccessfulPipelineSha
    echo "\t\turl: "$lastSuccessfulPipelineUrl

    environments=$(curl --header "PRIVATE-TOKEN: $API_TOKEN" "$API_BASE_URL/$pjEncoded/environments" 2> /dev/null)

    stagEnvId=$(echo $environments | jq 'map(select(.name == "staging")) | first | .id')
    stagEnv=$(curl --header "PRIVATE-TOKEN: $API_TOKEN" "$API_BASE_URL/$pjEncoded/environments/$stagEnvId" 2> /dev/null)
    stagCommit=$(echo $stagEnv | tr '\r\n' ' ' | tr '\t' ' ' | jq '.last_deployment.deployable.commit.id' | sed 's/"//g')
    stagPipelineId=$(echo $stagEnv | tr '\r\n' ' ' | tr '\t' ' ' | jq '.last_deployment.deployable.pipeline.id')
    stagPipelineUrl=$(echo $stagEnv | tr '\r\n' ' ' | tr '\t' ' ' | jq '.last_deployment.deployable.pipeline.web_url' | sed 's/"//g')

    prodEnvId=$(echo $environments | jq 'map(select(.name == "production")) | first | .id')
    prodEnv=$(curl --header "PRIVATE-TOKEN: $API_TOKEN" "$API_BASE_URL/$pjEncoded/environments/$prodEnvId" 2> /dev/null)
    prodCommit=$(echo $prodEnv | tr '\r\n' ' ' | tr '\t' ' ' | jq '.last_deployment.deployable.commit.id' | sed 's/"//g')
    prodPipelineId=$(echo $prodEnv | tr '\r\n' ' ' | tr '\t' ' ' | jq '.last_deployment.deployable.pipeline.id')
    prodPipelineUrl=$(echo $prodEnv | tr '\r\n' ' ' | tr '\t' ' ' | jq '.last_deployment.deployable.pipeline.web_url' | sed 's/"//g')

    echo "\tStaging:"
    if [ "$lastCommit" != "$stagCommit" ]; then
        echo "\t\t"$_OUTDATED_MESSAGE
        echo "\t\tDiff: "${BASE_URL}"/"${pj}"/compare/"$stagCommit"...master"
    fi
    echo "\t\tCommit: "$stagCommit
    echo "\t\tPipeline: "$stagPipelineUrl

    echo "\tProduction:"
    if [ "$lastCommit" != "$prodCommit" ]; then
        echo "\t\t"$_OUTDATED_MESSAGE
        echo "\t\tDiff: "${BASE_URL}"/"${pj}"/compare/"$prodCommit"...master"
    fi
    echo "\t\tCommit: "$prodCommit
    echo "\t\tPipeline: "$prodPipelineUrl

    echo ""
done
