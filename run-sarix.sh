#!/bin/bash

#
# A wrapper script to run the sarix model, messaging slack with progress and results.
#
# Environment variables (see README.md for details):
# - `SLACK_API_TOKEN`, `CHANNEL_ID` (required): used by slack.sh
# - `GH_TOKEN`, `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GIT_CREDENTIALS` (required): used by load-env-vars.sh
# - `DRY_RUN` (optional): when set (to anything), stops git commit actions from happening (default is to do commits)
#

#
# load environment variables and then slack functions
#

#echo "sourcing: load-env-vars.sh"
#source "$(dirname "$0")/load-env-vars.sh"

#echo "sourcing: slack.sh"
#source "$(dirname "$0")/../aws-vm-scripts/slack.sh"

#
# start
#

#slack_message "entered. id='$(id -u -n)', HOME='${HOME}', PWD='${PWD}', dirname=$(dirname "$0")"
echo "entered. id='$(id -u -n)', HOME='${HOME}', PWD='${PWD}', dirname=$(dirname "$0")"

#
# todo xx pre-model git operations
#

#
# run the model
#

#slack_message "running make"
echo "running make"
#make -C "$(dirname "$0")" sarix >${OUT_FILE} 2>&1
make -C "$(dirname "$0")" sarix
MAKE_RESULT=$?

if [ ${MAKE_RESULT} -ne 0 ]; then
  # make had errors
  #slack_message "make failed"
  echo "make failed"
  #slack_upload ${OUT_FILE}
  exit 1 # fail
fi

#
# todo xx post-model git operations
#

# model output(s):
# - 'weekly-submission/sarix-forecasts/UMass-sarix/<forecast_date>-UMass-sarix.csv'
# - plots?

#
# done
#

#slack_message "done"
echo "done"
exit 0 # success
