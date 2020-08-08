#!/bin/bash

###########################################################################################################
# import parameters and utility functions 
###########################################################################################################
. ${STARTING_DIR}/bin/provider/aws/demo.properties
. ${STARTING_DIR}/bin/provider/aws/utils.sh
. ${STARTING_DIR}/bin/provider/aws/.info

#####################################################
#	Step 1: install the AWS cli
#####################################################
install_aws_cli


#####################################################
# check if all necessary parameters have been exported
#####################################################
if [ "${AWS_ACCESS_KEY_ID}" = "" ] || [ "${AWS_SECRET_ACCESS_KEY}" = "" ]; then
  log "AWS credentials have not been exported. Please export AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY and try again. Exiting..."
  exit 1
fi
if [ "${AWS_REGION}" = "" ]; then
  log "AWS_REGION has not been exported.\n\nPlease export AWS_REGION and try again. Exiting..."
  exit 1
fi

#####################################################
#       Step 2: install the AWS prereqs
#####################################################
if [ $setup_prereqs = true ]; then 
  create_prereqs
fi


#####################################################
#       Step 3: create ec2 instance 
#####################################################
if [ $setup_onenode = true ]; then
  create_onenode_instance
  check_ec2 ${oneNodeInstanceId:?}
  associate_eip_2_instance
fi

#####################################################
#       Step 4: copy pem file to bind mount
#####################################################
if [ $setup_prereqs = true ]; then
  replicate_key
fi

#####################################################
#       Step 5: Generate connection strings
#####################################################
. ${STARTING_DIR}/bin/provider/aws/echo_conn_strings.sh
