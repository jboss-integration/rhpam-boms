#!/bin/sh

# Require BASH 3 or newer

REQUIRED_BASH_VERSION=3.0.0

if [[ $BASH_VERSION < $REQUIRED_BASH_VERSION ]]; then
  echo "You must use Bash version 3 or newer to run this script"
  exit
fi

if [[ -z "$RELEASE_REPO_URL" ]]; then
  echo "You must set the RELEASE_REPO_URL environment variable to your local checkout of https://github.com/jboss-developer/temp-maven-repo"
  exit
fi

# Canonicalise the source dir, allow this script to be called anywhere
DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

# DEFINE

# EAP team email subject
EMAIL_SUBJECT="\${RELEASEVERSION} of JBoss BOMs released, please merge with http://github.com/jboss-eap/jboss-bom, tag and add to EAP maven repo build"
# EAP team email To ?
EMAIL_TO="pgier@redhat.com kpiwko@redhat.com"
EMAIL_FROM="\"JDF Publish Script\" <benevides@redhat.com>"

JIRA_PROJECT="12310320"
#JIRA PLAYGROUND -- JIRA_PROJECT="10073"
JIRA_TO="pgier"
JIRA_SUMMARY="Upgrade rhpam-bom project in RHPAM"
JIRA_DESCRIPTION="The \${RELEASEVERSION} version of the jboss-rhpam-bom project has been released upstream. This needs to be merge with the eap branch and built for the eap Maven repo."


# SCRIPT

usage()
{
cat << EOF
usage: $0 options

This script performs a release of the BOMs 

OPTIONS:
   -s      Snapshot version number to update from
   -n      New snapshot version number to update to, if undefined, defaults to the version number updated from
   -r      Release version number
EOF
}

notify_email()
{
   echo "***** Performing JBoss BOM release notifications"
   echo "*** Notifying JBoss EAP team"
   subject=`eval echo $EMAIL_SUBJECT`
   echo "Email from: " $EMAIL_FROM
   echo "Email to: " $EMAIL_TO
   echo "Subject: " $subject
   # send email using sendmail
   printf "Subject: $subject\nSee \$subject :)\n" | /usr/bin/env sendmail -f "$EMAIL_FROM" "$EMAIL_TO"
}

notify_jira()
{
    echo -n "Please enter your JIRA username: "
    read username
    echo -n "Please enter your JIRA password: "
    read password
    description=`eval echo $JIRA_DESCRIPTION`
    curl -u $username:$password -X POST -H 'Content-Type: application/json' -d "{ \"fields\": { \"project\": {  \"id\": \"$JIRA_PROJECT\" },\"issuetype\": {\"id\": \"12\" },\"assignee\": { \"name\": \"$JIRA_TO\"}, \"summary\": \"$JIRA_SUMMARY\", \"description\": \"$description\"}}"   https://issues.jboss.org/rest/api/2/issue
    echo
    echo "JIRA Opened"
}

release()
{
   echo "Releasing JBoss BOMs version $RELEASEVERSION"
   $DIR/release-utils.sh -u -o $SNAPSHOTVERSION -n $RELEASEVERSION
   git commit -a -m "Prepare for $RELEASEVERSION release"
   git tag -a $RELEASEVERSION -m "Tag $RELEASEVERSION"
   $DIR/release-utils.sh -r
   $DIR/release-utils.sh -u -o $RELEASEVERSION -n $NEWSNAPSHOTVERSION
   git commit -a -m "Prepare for development of $NEWSNAPSHOTVERSION"
   git push upstream HEAD --tags
   echo "***** JBoss RHPAM BOMs released"
   read -p "Do you want to send release notifcations to $EAP_EMAIL_TO[y/N]? " yn
   case $yn in
       [Yy]* ) notify_email;;
       * ) exit;
   esac
}

SNAPSHOTVERSION="UNDEFINED"
RELEASEVERSION="UNDEFINED"
NEWSNAPSHOTVERSION="UNDEFINED"

while getopts “n:r:s:” OPTION

do
     case $OPTION in
         h)
             usage
             exit
             ;;
         s)
             SNAPSHOTVERSION=$OPTARG
             ;;
         r)
             RELEASEVERSION=$OPTARG
             ;;
         n)
             NEWSNAPSHOTVERSION=$OPTARG
             ;;
         [?])
             usage
             exit
             ;;
     esac
done

if [ "$NEWSNAPSHOTVERSION" == "UNDEFINED" ]
then
   NEWSNAPSHOTVERSION=$SNAPSHOTVERSION
fi

if [ "$SNAPSHOTVERSION" == "UNDEFINED" -o  "$RELEASEVERSION" == "UNDEFINED" ]
then
   echo "\nMust specify -r and -s\n"
   usage
else  
   release
fi


