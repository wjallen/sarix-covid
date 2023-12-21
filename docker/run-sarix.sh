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

echo "sourcing: load-env-vars.sh"
source "/app/container-utils/scripts/load-env-vars.sh"

echo "sourcing: slack.sh"
source "/app/container-utils/scripts/slack.sh"

#
# start
#

slack_message "starting. id='$(id -u -n)', HOME='${HOME}', PWD='${PWD}', DRY_RUN='${DRY_RUN+x}'"

#
# run the model
#

OUT_FILE=/tmp/run-sarix-out.txt

slack_message "running make"
make -C "$(dirname "$0")" sarix >${OUT_FILE} 2>&1
MAKE_RESULT=$?

if [ ${MAKE_RESULT} -ne 0 ]; then
  # make had errors
  slack_message "make failed"
  slack_upload ${OUT_FILE}
  exit 1 # fail
fi

# make had no errors. find PDF and CSV files, add new CSV file to new branch, and then upload the PDF.
# example output files (under /app):
#   ./weekly-submission/sarix-forecasts/UMass-sarix/2023-12-19-UMass-sarix.csv
#   ./weekly-submission/sarix-plots/2023-12-19/UMass-sarix.pdf

slack_message "make OK; collecting PDF and CSV files"
CSV_FILES=$(find "/app/weekly-submission" -type f -name "*.csv")
NUM_CSV_FILES=$(echo "${CSV_FILES}" | wc -l)
if [ "${NUM_CSV_FILES}" -ne 1 ]; then
  slack_message "CSV_FILES error: not exactly 1 CSV file. CSV_FILES=${CSV_FILES}, NUM_CSV_FILES=${NUM_CSV_FILES}"
  slack_upload ${OUT_FILE}
  exit 1 # fail
fi

PDF_FILES=$(find "/app/weekly-submission" -type f -name "*.pdf")
NUM_PDF_FILES=$(echo "${PDF_FILES}" | wc -l)
if [ "${NUM_PDF_FILES}" -ne 1 ]; then
  slack_message "PDF_FILES error: not exactly 1 PDF file. PDF_FILES=${PDF_FILES}, NUM_PDF_FILES=${NUM_PDF_FILES}"
  slack_upload ${OUT_FILE}
  exit 1 # fail
fi

# found exactly one CSV and one PDF file
CVS_FILE=${CSV_FILES}
PDF_FILE=${PDF_FILES}
slack_message "found: CVS_FILE=${CVS_FILE}, PDF_FILE=${PDF_FILE}"

if [ -n "${DRY_RUN+x}" ]; then # yes DRY_RUN
  slack_message "DRY_RUN set, exiting"
  exit 0 # success
fi

# create and push a branch with the new CSV file. we first sync fork w/upstream and then push to the fork b/c sometimes
# a PR will fail to be auto-merged, which we think is caused by an out-of-sync fork

HUB_DIR="/data/covid19-forecast-hub" # a fork

# delete old branch
slack_message "deleting old branch"
BRANCH_NAME='sarix'
git -C "${HUB_DIR}" branch --delete --force ${BRANCH_NAME} # delete local branch
git -C "${HUB_DIR}" push origin --delete ${BRANCH_NAME}    # delete remote branch

# update forked HUB_DIR
slack_message "updating forked HUB_DIR=${HUB_DIR}"
cd "${HUB_DIR}"
git fetch upstream # pull down the latest source from original repo
git checkout master
git merge upstream/master # update fork from original repo to keep up with their changes
git push origin master    # sync with fork

# create new branch, add the .csv file, xx
slack_message "creating branch and pushing"
TODAY_DATE=$(date +'%Y-%m-%d') # e.g., 2022-02-17
git checkout -b ${BRANCH_NAME}
cp "${CVS_FILE}" "${HUB_DIR}/data-processed/UMass-sarix"
git add data-processed/UMass-sarix/\*
git commit -m "sarix build, ${TODAY_DATE}"
git push -u origin ${BRANCH_NAME}
PUSH_RESULT=$?

if [ ${PUSH_RESULT} -ne 0 ]; then
  slack_message "push failed"
  slack_upload ${OUT_FILE}
  exit 1 # fail
fi

PR_URL=$(gh pr create --title "${TODAY_DATE} sarix" --body "sarix, COVID19 Forecast Hub")
if [ $? -eq 0 ]; then
  slack_message "PR OK. PR_URL=${PR_URL}"
else
  slack_message "PR failed"
  exit 1 # fail
fi

# upload PDF
slack_upload "${PDF_FILE}"

#
# done
#

slack_message "done"
exit 0 # success
