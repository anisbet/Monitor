#!/bin/bash
###############################################################################
#
# monitor.sh keeps track that a specific process is running and sends an (one)
# email if it is not.
# 
#  Copyright 2023 Andrew Nisbet
#  
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#  
#       http://www.apache.org/licenses/LICENSE-2.0
#  
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# Wed 07 Jun 2023 11:23:35 AM EDT
#
###############################################################################
set -o pipefail

. ~/.bashrc
##### Non-user-related variables ########
VERSION="1.0.7"
applications=()
is_test=false
MONITOR_DIR="/software/EDPL/Unicorn/EPLwork/cronjobscripts/Monitor"
MAIL_SERVICE="mailx"
MONITOR_APP=$(basename "$0")
## Set up logging.
LOG_FILE="$MONITOR_DIR/monitor.log"
# Logs messages to STDERR and $LOG file.
# param:  Log file name. The file is expected to be a fully qualified path or the output
#         will be directed to a file in the directory the script's running directory.
# param:  Message to put in the file.
# param:  (Optional) name of a operation that called this function.
logit()
{
    local message="$1"
    local time=''
    time=$(date +"%Y-%m-%d %H:%M:%S")
    if [ -t 0 ]; then
        # If run from an interactive shell message STDERR.
        echo -e "[$time] $message" >&2
    fi
    echo -e "[$time] $message" >>$LOG_FILE
}
# Prints out usage message.
usage()
{
    cat << EOFU!
 Usage: $0 [flags]

Monitors a given process and sends an email if it is not running.
An email will be sent once a day while the target application is not found to be running.

Flags:
-a, -app, --app="bar.sh fizz.sh": Specifies the application(s) to monitor.
-e, -email, --email="user@example.com customer@example.com": Specifies the email addressees.
-h, -help, --help: This help message.
-t, -test, --test: Display debug information to STDOUT.
-v, -version, --version: Print watcher.sh version and exits.
 Example:
    ${0} --app="cleanup.sh watcher.sh loadusers.lp.sh"
EOFU!
}

### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "app:,email:,help,test,version" -o "a:e:htv" -a -- "$@")
if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi
# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"

while true
do
    case $1 in
    -a|--app)
        shift
        # Read all the space-separated names of the --app argument string as separate app names.
        app_ref="$1"
        read -ra applications <<< "$1"
        ;;
    -e|--email)
        shift
        email_addresses="$1"
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    -t|--test)
        is_test=true
        ;;
    -v|--version)
        echo "$0 version: $VERSION"
        exit 0
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done
# Required applications and email addresses check.
: "${applications:?Missing -a,--app}" "${email_addresses:?Missing -e,--email}"
[ "$is_test" == true ] && logit "$MONITOR_APP version $VERSION Checking: $app_ref"
# Logs and send email if this is the first time today the script notices the application not running.
# param:  Application targetted for monitoring.
message_staff()
{
    local app=''
    app=$(basename "$1")
    local readable_date
    readable_date=$(date)
    local warning_message="**Attention, on $readable_date monitored application $app is NOT running!\nPlease investigate.\n"
    local today=''
    today=$(date +'%Y%m%d')
    local notified="$MONITOR_DIR/${app}.notified.log"
    local mailer=''
    mailer=$(which "$MAIL_SERVICE")
    touch "$notified"
    local last_notified=''
    last_notified=$(tail -n 1 "$notified")
    if [ "$last_notified" == "" ] || [ "$last_notified" -ne "$today" ]; then
        # Email addressees
        logit "$email_addresses emailed about $app failure on $readable_date"
        if [ -z "$mailer" ] || [ ! -f "$mailer" ]; then
            logit "*error, no mail service $mailer!"
        else
            echo -e "$warning_message" | $mailer -s"** Process $app failed on $readable_date **" "$email_addresses"
        fi
        # Save the date so we don't spam until and only if the application is still not running tomorrow.
        echo "$today" >>"$notified"
    fi
}

# Grep out the name of the script as well because the --app param is found by grep.
for application in "${applications[@]}"; do
    # Use ps and not pgrep because more control to match partial script names.
    result=$(ps aux | grep -i "$application" | grep -v "grep" | grep -v "$0")
    if [ -z "$result" ]; then
        message_staff "$application"
        if [ "$is_test" == true ]; then
            logit "TEST: $application is NOT running"
        fi
    else
        # If there is another process watching the --dir watch directory, exit quietly.
        if [ "$is_test" == true ]; then
            logit "TEST: $application is running"
        fi
    fi
done
