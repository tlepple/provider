#!/bin/bash

#########################################################
# utility functions
#########################################################
#dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

STARTING_DIR=`pwd`
# logging function
log() {
    echo -e "[$(date)] [$BASH_SOURCE: $BASH_LINENO] : $*"
}



#########################################################
# start the cloud instance
#########################################################
# set the variables from .info

. ${STARTING_DIR}/bin/provider/aws/.info
. ${STARTING_DIR}/bin/provider/aws/utils.sh

echo "instance id --> " ${oneNodeInstanceId}


########################################################
# set the current RUN_STATE and start the instance if stopped
#########################################################
  export RUN_STATE=$(aws ec2 describe-instances --instance-ids ${oneNodeInstanceId} \
  --query Reservations[].Instances[].State.Code \
  --output text)
  echo "Current run state is: "$RUN_STATE

###
  if (( $RUN_STATE == 80 ));
  then
        echo "Instance " ${oneNodeInstanceId} " is Stopped"
#          # Time to start the instance:
	echo "Starting instanceID = " ${oneNodeInstanceId}
	aws ec2 start-instances --instance-ids ${oneNodeInstanceId}
  else
    echo "Instance " ${oneNodeInstanceId} " is in a different state."
  fi

# call the check instance status function:
check_ec2 ${oneNodeInstanceId}


# call echo_conns here:
. ${STARTING_DIR}/bin/provider/aws/echo_conn_strings.sh
