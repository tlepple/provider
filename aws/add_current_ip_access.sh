#!/bin/bash

# define starting dir
STARTING_DIR=`pwd`
echo ${STARTING_DIR}

###########################################################################################################
# import parameters and utility functions 
###########################################################################################################
#. $starting_dir/provider/aws/demo.properties
. ${STARTING_DIR}/bin/provider/aws/utils.sh
. ${STARTING_DIR}/provider/aws/.info


# function for logging
log() {
    echo "[$(date)]: $*"
}
# set your current ip address
current_ip=`curl -s ipinfo.io/ip`

log "Adding IP --> " ${current_ip:?}
add_ip_access_rule ${current_ip:?}
