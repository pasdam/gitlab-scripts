#!/bin/sh

PROJECT_PATH=pasdam/forex-wallet
API_TOKEN=KS16gqLnBNMwKyA9JD8K
LABELS_FILE=/Users/paco/Downloads/labels.json

print_usage() {
	SCRIPT_NAME="${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}"
	echo "Usage: $SCRIPT_NAME [-u <host>] -p <project_path> -t <token> [-o <operation>] [<labels_file>"]
    echo ""
    echo "Parameters:"
    echo "u""\t\t""(optional) host url (default https://gitlab.com/)"
    echo "p""\t\t""project path, i.e username/project-name"
    echo "t""\t\t""access token enabled for API usage"
    echo "o""\t\t""(optional) the operation to perform, add (default) or list labels"
    echo "labels_file""\t""is a json file with an array of labels, with only two fields, name and color. This is mandatory for an add operation"
}

while getopts 'hu:p:t:o:' option
do
	case "${option}"
	in
		u) GITLAB_HOST=$OPTARG;;
		p) PROJECT_PATH=$OPTARG;;
		t) API_TOKEN=$OPTARG;;
		o) OPERATION=$OPTARG;;
		
        : ) echo "Missing option argument for -$OPTARG" >&2; exit 2;;

		h) print_usage; exit 0;;
		\?) print_usage; exit 1;;
	esac
done

# check mandatory parameters
if [ -z "$PROJECT_PATH" ]; then
	echo "Project path (-p) not specified" >&2
	exit 2
fi
if [ -z "$API_TOKEN" ]; then
	echo "Access token (-t) not specified" >&2
	exit 3
fi

# set defaults
if [ -z "$GITLAB_HOST" ]; then
    GITLAB_HOST=https://gitlab.com/
fi
if [ -z "$OPERATION" ]; then
    OPERATION=add
fi

API_BASE_URL=${GITLAB_HOST}"api/v4/projects/"${PROJECT_PATH//\//%2F}""
API_PATH_LABELS=${API_BASE_URL}"/labels"

if [ "${OPERATION}" == "add" ]; then
    # add labels
    if [ -z "$LABELS_FILE" ]; then
        echo "Labels file not specified" >&2
        exit 4
    fi

    cat ${LABELS_FILE} | jq -r '.[] | [.name, .color] | @tsv' |
    while IFS=$'\t' read -r name color email; do
        curl --header "PRIVATE-TOKEN: $API_TOKEN" -X POST ${API_PATH_LABELS} --data-urlencode "name="$name --data-urlencode "color="$color
        echo ""
    done
    
elif [ "${OPERATION}" == "list" ]; then
    # Read labels
    echo "Current labels:"
    curl --header "PRIVATE-TOKEN: $API_TOKEN" -X GET ${API_PATH_LABELS} 2> /dev/null | jq

else
    echo "Unrecognized operation: "${OPERATION}
    exit 5
fi
