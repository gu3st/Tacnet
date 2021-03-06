#!/bin/bash
set -e # Exit on error

user='tacnet-www'
target='tacnet.io'
port=''
branch='master'
prod_folder='/home/tacnet-www/www/'

# Help
function usage {
    echo "Usage: prod_deploy [-q]"
    echo "Arguments:"
    echo "  -t  --test:  Test deploy"
}

test_build=false

while [ "$1" != "" ]; do
    case $1 in
        -t | --test )           test_build=true
                                ;;
        -h | --help | -q)       usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

if [ "$test_build" == true ]; then
    prod_folder='/home/tacnet-www/test/'
fi

ssh eirikmsy@$target -t '

    sudo su '$user' -c "
        cd '$prod_folder'
        git fetch
        git reset --hard origin/'$branch'
        source venv/bin/activate
        pip install -r requirements.txt
        python tacnet/manage.py syncdb --migrate
        python tacnet/manage.py collectstatic --noinput --clear
        '$full'
    "

    cd '$prod_folder'
    DESCRIPTION=$(git log -1 HEAD --pretty=format:%s)
    REVERSION=$(git rev-parse HEAD)
    AUTHOR=$(git log -1 HEAD --pretty=format:"%an")
    curl -H "x-api-key:" -d "deployment[application_id]=" -d "deployment[description]=$(git log -1 HEAD --pretty=format:%s)" -d "deployment[revision]=$REVERSION" -d "deployment[user]=$AUTHOR"  https://rpm.newrelic.com/deployments.xml


    sudo supervisorctl reload
    sudo service nginx stop
    sudo service nginx start

'

