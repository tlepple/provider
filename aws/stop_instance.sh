#!/bin/bash

#########################################################
# utility functions
#########################################################
#dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

STARTING_DIR=`pwd`


#########################################################
# start the cloud instance
#########################################################
# set the variables from .info

. ${STARTING_DIR}/bin/provider/aws/.info

echo "instance id --> " ${oneNodeInstanceId}

########################################################
# set the current RUN_STATE and start the instance if stopped
#########################################################
  export RUN_STATE=$(aws ec2 describe-instances --instance-ids ${oneNodeInstanceId} \
  --query Reservations[].Instances[].State.Code \
  --output text)
  echo "Current run state is: "$RUN_STATE

###
  if (( $RUN_STATE == 16 ));
  then
        echo "Instance " ${oneNodeInstanceId} " is Running"
#          # Time to stop the instance:
	echo "Stopping instanceID = " ${oneNodeInstanceId}
	aws ec2 stop-instances --instance-ids ${oneNodeInstanceId}
  else
    echo "Instance " ${oneNodeInstanceId} " is in a different state."
  fi

