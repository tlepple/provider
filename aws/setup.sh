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
