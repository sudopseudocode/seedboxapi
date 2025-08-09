#!/bin/sh

if [ "$DEBUG" != "" ]; then
  set -x
fi

# The directory to store the two state files - /config is a docker standard
OLD_IP_FILE=/tmp/MAM.ip
RESPONSE_FILE=/tmp/MAM.output
TEMP_COOKIE_FILE=/tmp/MAM.cookies
COOKIE_FILE=/config/MAM.cookies

if [ -z "$interval" ]; then
  echo "Running with default interval of 1 minute"
  SLEEPTIME=60
elif [ "$interval" -lt "1" ]; then
  echo "Cannot set interval to less than 1 minute"
  echo "  => Running with default interval of 60 seconds"
  SLEEPTIME=60
else
  echo "Running with an interval of $interval minute\(s\)"
  SLEEPTIME=$(expr "$interval" \* 60)
fi

grep mam_id ${COOKIE_FILE} >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then
  if [ -z "$mam_id" ]; then
    echo "no mam_id, and no existing session."
    exit 1
  fi

  echo "No existing session, creating new cookie file using mam_id from environment"
  printf ".t.myanonamouse.net\tTRUE\t/\tFALSE\t0\tmam_id\t%s" "$mam_id" >"$COOKIE_FILE"
fi

# Unlike curl, wget only saves cookies on successful HTTP requests
wget \
  --load-cookies="$COOKIE_FILE" \
  --save-cookies="$COOKIE_FILE" \
  --keep-session-cookies \
  -O "$RESPONSE_FILE" \
  "$MAM_URL" >/dev/null

grep '"Success":true' $RESPONSE_FILE >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then
  echo "Response: $(cat $RESPONSE_FILE)"
  echo "Current cookie file is invalid.  Please delete it, set the mam_id, and restart the container."
  exit 1
else
  echo "Session is valid"
fi

OLD_IP=$(cat $OLD_IP_FILE 2>/dev/null)

while [ $PPID -ne 1 ]; do
  OLD_IP=$(cat $OLD_IP_FILE 2>/dev/null)
  NEW_IP=$(curl -s ip4.me/api/ | md5sum - | awk '{print $1}')

  if [ "$DEBUG" != "" ]; then
    echo "Current IP:  $(curl -s ip4.me/api/)"
  fi

  # Check to see if the IP address has changed
  if [ "$OLD_IP" != "$NEW_IP" ]; then
    echo "New IP detected"
    # Unlike curl, wget only saves cookies on successful HTTP requests
    wget \
      --load-cookies="$COOKIE_FILE" \
      --save-cookies="$COOKIE_FILE" \
      --keep-session-cookies \
      -O "$RESPONSE_FILE" \
      "$MAM_URL" >/dev/null

    grep -E 'No Session Cookie|Invalid session' $RESPONSE_FILE >/dev/null 2>/dev/null
    if [ $? -eq 0 ]; then
      echo "Response: $(cat $RESPONSE_FILE)"
      echo "Current cookie file is invalid.  Please delete it, set the mam_id, and restart the container."
      exit 1
    fi

    # If that command worked, and we therefore got the success message
    # from MAM, update the OLD_IP_FILE for the next execution
    grep '"Success":true' $RESPONSE_FILE >/dev/null 2>/dev/null
    if [ $? -eq 0 ]; then
      echo "Response:  \"$(cat $RESPONSE_FILE)\""
      # Update COOKIE_FILE only on successful requests
      mv $TEMP_COOKIE_FILE $COOKIE_FILE
      echo "$NEW_IP" >$OLD_IP_FILE
      OLD_IP=$NEW_IP
    else
      grep "Last change too recent" $RESPONSE_FILE >/dev/null 2>/dev/null
      if [ $? -eq 0 ]; then
        echo "Last update too recent - sleeping"
      else
        echo "Response: $(cat $RESPONSE_FILE)"
        echo "Invalid response"
        exit 1
      fi
    fi
  else
    echo "No IP change detected: $(date)"
  fi
  sleep "$SLEEPTIME"

  # Empty the IP file if it has not been rotated for more than 30 days, this will enforce session freshness.
  find $OLD_IP_FILE -mtime +30 -delete
done
