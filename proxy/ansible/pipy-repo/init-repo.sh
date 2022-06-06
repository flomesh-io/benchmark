#!/bin/sh

# set -ex

REPO_HOST=${1:-localhost:6060}

for repo in `ls -d */`
do
    repo=${repo%%/}
	# create repo
	curl -X POST http://$REPO_HOST/api/v1/repo/$repo
	curl -X DELETE http://$REPO_HOST/api/v1/repo/$repo/main.js

	find $repo -type f | egrep -v ".*\.sh|.*\.py" | cut -d / -f 2- | while read line;
	do
		echo $repo/$line
		curl -X POST http://$REPO_HOST/api/v1/repo/$repo/$line --data-binary "@./$repo/$line"

	done;
	# release
	curl -X POST http://$REPO_HOST/api/v1/repo/$repo --data '{"main":"/main.js"}'
	curl -X POST http://$REPO_HOST/api/v1/repo/$repo --data '{"version": '$(date +%s)'}'

done
