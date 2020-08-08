#!/bin/bash

# define starting dir
STARTING_DIR=`pwd`
echo ${STARTING_DIR}

###########################################################################################################
# import parameters and utility functions 
###########################################################################################################
#. ${starting_dir}/provider/aws/demo.properties
. ${STARTING_DIR}/bin/provider/aws/utils.sh
. ${STARTING_DIR}/bin/provider/aws/.info


# function for logging
log() {
    echo "[$(date)]: $*"
    echo "[$(date)]: $*" >> terminate.log
}

#delete the instance(s)
terminate_all_ec2 

#archive .info file
archive_info_file
