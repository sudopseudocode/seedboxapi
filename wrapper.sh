#!/bin/sh

if [ "x$DEBUG" != "x" ]
then
	set -x
fi

# The directory to store the two state files - /config is a docker standard
CACHEFILE=/tmp/MAM.ip
COOKIEFILE=/config/MAM.cookies

if [ "x$interval" == "x" ]
then
	echo Running with default interval of 1 minute
	SLEEPTIME=60
else
	if [ "$interval" -lt "1" ]
	then
		echo Cannot set interval to less than 1 minute
		echo "  => Running with default interval of 60 seconds"
		SLEEPTIME=60
	else
		echo Running with an interval of $interval minute\(s\)
		SLEEPTIME=`expr $interval \* 60`
	fi
fi

grep mam_id ${COOKIEFILE} > /dev/null 2>/dev/null
if [ $? -ne 0 ]
then
	if [ "x$mam_id" == "x" ]
	then
		echo no mam_id, and no existing session.
		exit 1
	fi

	echo No existing session, creating new cookie file using mam_id from environment
	curl -s -b mam_id=${mam_id} -c ${COOKIEFILE} https://t.myanonamouse.net/json/dynamicSeedbox.php > /tmp/MAM.output
	grep '"Success":true' /tmp/MAM.output > /dev/null 2>/dev/null
  	if [ $? -ne 0 ]
  	then
		echo mam_id passed on command line is invalid
		exit 1
	fi
fi

OLDIP=`cat $CACHEFILE 2>/dev/null`

while [ $PPID -ne 1 ]
do
	OLDIP=`cat $CACHEFILE 2>/dev/null`

	NEWIP=`curl -s ip4.me/api/ | md5sum - | awk '{print $1}'`
	if [ "x$DEBUG" != "x" ]
	then
		echo Current IP:  `curl -s ip4.me/api/`
	fi
	
	# Check to see if the IP address has changed
	if [ "${OLDIP}" != "${NEWIP}" ]
	then
  		echo New IP detected
  		curl -s -b $COOKIEFILE -c $COOKIEFILE https://t.myanonamouse.net/json/dynamicSeedbox.php > /tmp/MAM.output

		grep -E 'No Session Cookie|Invalid session' /tmp/MAM.output > /dev/null 2>/dev/null
		if [ $? -eq 0 ]
		then
			echo Invalid session
			exit 1
		fi
	
  		# If that command worked, and we therefore got the success message
  		# from MAM, update the CACHEFILE for the next execution
		grep '"Success":true' /tmp/MAM.output > /dev/null 2>/dev/null
  		if [ $? -eq 0 ]
  		then
			echo Response:  \"`cat /tmp/MAM.output`\"
    			echo $NEWIP > $CACHEFILE
			OLDPID=$NEWIP
		else
			grep 'Last change too recent' /tmp/MAM.output > /dev/null 2>/dev/null
			if [ $? -eq 0 ]
			then
				echo Last update too recent - sleeping
			else
				echo Invalid response \"`cat /tmp/MAM.output`\"
				exit 1
			fi
  		fi
	else
		echo "No IP change detected: `date`"
	fi
	sleep $SLEEPTIME
done
