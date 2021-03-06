#!/bin/bash

. /readthedocs/functions.sh

PARENT=''
QUERY="trashed = false and name = 'readthedocs'"

if [ -z "$GDRIVE_RTD_ROOT" ]; then
  echo 'Looks like you do not have your GDRIVE_RTD_ROOT'
  echo 'environment variable set. Searching for any folder'
  echo 'in your Google Drive named readthedocs:'
  echo

  GDRIVE_RTD_ROOT=$(gdrive list --no-header -q "$QUERY" | awk '{print $1}')
  if [ -n "$GDRIVE_RTD_ROOT" ]; then
	echo 'Found it! Using folder named 'readthedocs' with ID '$GDRIVE_RTD_ROOT
	echo 'Make these messages go away by adding the following to your profile:'
	echo 
	echo "export GDRIVE_RTD_ROOT='$GDRIVE_RTD_ROOT'"
	echo
  else 
	echo "Could not find any folder named 'readthedocs'. Please make sure"
	echo "to rename the root used to readthedocs. Exiting with non-zero status."
	echo 1
  fi
else
  echo "GDRIVE_RTD_ROOT set to $GDRIVE_RTD_ROOT, checking folder name ..."
  PARENT="$(gdrive list -m 1000 -q "sharedWithMe or 'me' in readers" | grep $GDRIVE_RTD_ROOT | awk '{print $2}')"
  echo "GDRIVE_RTD_ROOT folder name = $PARENT"
  if [ "$PARENT" != "readthedocs" ]; then
	echo "The folder name associated with your GDRIVE_RTD_ROOT id is not"
	echo "named readthedocs. It is named '$FOLDER' instead. Please make"
	echo "sure you used the correct folder ID, or your folder is renamed."
	echo "It MUST be named 'readthedocs'. Exiting with non-zero status."
	exit 1
  fi
fi

cd /readthedocs
QUERY="$(query $GDRIVE_RTD_ROOT)"

dl_dir "$GDRIVE_RTD_ROOT"
