#!/bin/bash -e

source config
hook_file=$(pwd)/commit-msg

BRANCH_NAME=sync_transifex

function transfer_jenkins_env(){
    case "$1" in
    UploadPot)
        action="upload"
        ;;
    DownloadPo)
        action="download"
        ;;
    *)
        usage
        ;;
    esac

    _IFS=$IFS
    IFS='@'
    if [ -n "${GERRIT_PROJECT}" ] && [ -n "${GERRIT_BRANCH}" ]; then
        project=${GERRIT_PROJECT}
        branch=${GERRIT_BRANCH}
    else
        arr=($PROJECT)
        project=${arr[0]}
        branch=${arr[1]}
    fi
    IFS=$_IFS
}


try_download_CL()
{
    prj=$1
    json=$(curl -s "https://$GERRIT_HOST/changes/?q=topic:$BRANCH_NAME+project:$prj+status:open" | sed 1d)
    len=$(echo $json | jq '.|length')
    case $len in
	0)
	    echo "there hasn't any CL exists for $prj"
	    return 1
	    ;;
	1)
	    CL=$(echo $json | jq '.[0]._number')
	    echo "there found an exists CL $CL, using this CL to update POs"
	    git review -r origin -d $(echo $json | jq '.[0]._number')
	    return 0
	    ;;
	*)
	    echo "Two many exists CLs for $prj, do nothing" >> error.log
	    return 1
	    ;;
    esac
}

download()
{
    prj=$1
    branch=$2
    echo "download po from $prj $branch ..."
    savedDir=$(pwd)
    tmpDir="/tmp/sync-po-$prj"
    gitDir="ssh://$GERRIT_USER@$GERRIT_HOST:29418/$prj"
    echo "$gitDir"
    rm -rf $tmpDir
    git clone $gitDir $tmpDir
    cd $tmpDir
    git config user.email "transifex@deepin.com"
    git config user.name "transifex"
    cp $hook_file .git/hooks

    git checkout $branch
    if [ $? -ne 0 ]; then
	cd $savedDir
	rm -rf $tmpDir
	return
    fi

    if try_download_CL $prj; then
        # Set minimum percent of resource to 1
        tx pull -f -a --minimum-perc=1
        find -name "*.po" | xargs -n1 git add
        find -name "*.ts" | xargs -n1 git add
        git commit -a --amend --no-edit
    else
        git checkout -b "$BRANCH_NAME"
        tx pull -f -a --minimum-perc=1
        find -name "*.po" | xargs -n1 git add
        find -name "*.ts" | xargs -n1 git add
        git commit -a -m "auto sync po files from transifex"
    fi

    git remote set-url origin $gitDir
    git review -r origin -f $branch
    cd $savedDir
    rm -rf $tmpDir
}

init()
{
    # init param
    if [ $# == 1 ];then
        transfer_jenkins_env $@
    else
        echo "param not suport"
        usage
    fi

    # transifex
    cat > ~/.transifexrc <<EOF
[${TX_HOST}]
hostname = ${TX_HOST}
password = ${TX_PASSWORD}
token = 
username = ${TX_USER}
EOF

}

upload()
{
    #branch=$(get_work_branch $1)
    prj=$1
    branch=$2
    savedDir=$(pwd)
    echo "upload po to $1 $branch ..."
    tmpDir="/tmp/sync-po-$1"
    gitDir="ssh://$GERRIT_USER@$GERRIT_HOST:29418/$prj"
    echo "$gitDir"
    rm -rf $tmpDir
    git clone $gitDir $tmpDir
    cd $tmpDir

    git checkout $branch
    if [ $? -ne 0 ]; then
        cd $savedDir
        rm -rf $tmpDir
        return
    fi

    tx push -s
    cd $savedDir
    rm -rf $tmpDir
}

usage() { echo "Usage: $0 action " 1>&2; exit 1; }


declare action
declare project
declare branch

init $@

echo Action $action
if [ ! -n "$action" ]; then
    echo "action must be specified" 1>&2; exit 1
fi

case $action in
    "upload")
	if [ ! -n "$1" ]; then
        echo "project name must be specified" 1>&2; exit 1
	else
	    upload $project $branch
	fi
	;;
    "download")
	if [ ! -n "$1" ]; then
        echo "project name must be specified" 1>&2; exit 1
	else
	    download $project $branch
	fi
	;;
esac

