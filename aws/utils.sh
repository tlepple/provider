#!/bin/bash

###########################################################################################################
# Define Functions:
###########################################################################################################

#####################################################
# Function to install passwordless access to hosts
#####################################################
install_pwdless_access() {

	echo "-- Enable passwordless root login via rsa key"
	ssh-keygen -f ~/myRSAkey -t rsa -N ""
	mkdir ~/.ssh
	cat ~/myRSAkey.pub >> ~/.ssh/authorized_keys
	chmod 400 ~/.ssh/authorized_keys
	ssh-keyscan -H `hostname` >> ~/.ssh/known_hosts
	sed -i 's/.*PermitRootLogin.*/PermitRootLogin without-password/' /etc/ssh/sshd_config
	systemctl restart sshd

}


n to install jq
#####################################################
install_jq_cli() {

	#####################################################
	# first check if JQ is installed
	#####################################################
	echo "Installing jq"
	yum install -y unzip

	jq_v=`jq --version 2>&1`
	if [[ $jq_v = *"command not found"* ]]; then
	  curl -L -s -o jq "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64"
	  chmod +x ./jq
	  cp jq /usr/bin
	else
	  echo "jq already installed. Skipping"
	fi

	jq_v=`jq --version 2>&1`
	if [[ $jq_v = *"command not found"* ]]; then
	  #log "error installing jq. Please see README and install manually"
	  echo "Error installing jq. Please see README and install manually"
	  exit 1 
	fi  

}


#####################################################
# Function to install aws cli
#####################################################

install_aws_cli() {

	#########################################################
	# BEGIN
	#########################################################
	echo "BEGIN setup.sh"
	yum install -y unzip


	#####################################################
	# first check if JQ is installed
	#####################################################
	echo "Installing jq"

        jq_v=`jq --version 2>&1`
        if [[ $jq_v = *"command not found"* ]]; then
          curl -L -s -o jq "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64"
          chmod +x ./jq
          cp jq /usr/bin
        else
          echo "jq already installed. Skipping"
        fi

        jq_v=`jq --version 2>&1`
        if [[ $jq_v = *"command not found"* ]]; then
          echo "Error installing jq. Please see README and install manually"
          exit 1
        fi

	####################################################
 	# then install AWS CLI
	#####################################################
  	echo "Installing AWS_CLI"
  	aws_cli_version=`aws --version 2>&1`
  	echo "Current CLI version: $aws_cli_version"
  	if [[ $aws_cli_version = *"aws-cli"* ]]; then
    		echo "AWS CLI already installed. Skipping"
    		return
#  	fi
        else
  		curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  		unzip awscliv2.zip
  		./aws/install -i /usr/local/aws -b /usr/local/bin 
  		rm -rf aws*
  	echo "Done installing AWS CLI v2"
        fi
}

#####################################################
# Functions: create AWS prereqs (VPC, subnets, security group, db subnet)
#####################################################

create_prereqs() {
  if [ -s ${STARTING_DIR}/bin/provider/aws/.info ]; then
    log "Looks like you have not propertly terminated the previous environment, as there are still entries in .info. Execute first terminate.sh and rerun. Exiting..."
    exit 1
  fi


  #####################################################
  # record main info for the cluster
  #####################################################
  echo "AWS_REGION=${AWS_REGION:?}" > ${STARTING_DIR}/bin/provider/aws/.info
  echo "OWNER_TAG=${OWNER_TAG:?}" >> ${STARTING_DIR}/bin/provider/aws/.info
  echo "STARTING_DIR=${STARTING_DIR:?}" >> ${STARTING_DIR}/bin/provider/aws/.info
  echo "CLOUD_PROVIDER=${CLOUD_PROVIDER:?}" >> ${STARTING_DIR}/bin/provider/aws/.info

  #####################################################
  # create VPC
  #####################################################
  if [ "${MY_VPC}" = "" ]; then
    vpc_id=`aws --output json --region ${AWS_REGION:?} ec2 create-vpc --cidr-block 10.0.0.0/16 | jq -r ".Vpc.VpcId"`
    if [ "${vpc_id}" = "" ]; then
      log "VPC could not be created. Most likely the limit has beeen exceeded. Please pick a different region, or use an existing VPC by setting 'export MY_VPC=...' and rerun the script. Exiting..."
      exit 1
    fi
    echo "existingVpc=false" >> ${STARTING_DIR}/bin/provider/aws/.info
    aws --region ${AWS_REGION:?} ec2 create-tags --resources ${vpc_id:?} --tags Key=owner,Value=${OWNER_TAG:?} Key=Name,Value=${OWNER_TAG:?}-vpc
    log "New VPC in ${AWS_REGION:?} created: ${OWNER_TAG:?}-vpc, ${vpc_id:?}"
  else
    vpc_id="${MY_VPC}"
    echo "existingVpc=true" >> ${STARTING_DIR}/bin/provider/aws/.info
    log "Existing VPC in ${AWS_REGION:?} used: ${vpc_id:?}"
  fi
  echo "vpc_id=${vpc_id:?}" >> ${STARTING_DIR}/bin/provider/aws/.info
  aws --region ${AWS_REGION:?} ec2 modify-vpc-attribute --enable-dns-hostnames --vpc-id ${vpc_id:?}
 
  ##################################################### 
  # create public subnets
  #####################################################
  subnet_id=`aws --output json --region ${AWS_REGION:?} ec2 create-subnet --availability-zone ${AWS_REGION:?}a --vpc-id ${vpc_id:?} --cidr-block 10.0.8.0/24 | jq -r ".Subnet.SubnetId"`
  echo "subnet_id=${subnet_id:?}" >> ${STARTING_DIR}/bin/provider/aws/.info
  log "New Subnet in ${AWS_REGION:?}a created: ${OWNER_TAG:?}-subnet, ${subnet_id:?}"
  aws --region ${AWS_REGION:?} ec2 create-tags --resources ${subnet_id:?} --tags Key=owner,Value=${OWNER_TAG:?} Key=Name,Value=${OWNER_TAG:?}-subnet
 
  ##################################################### 
  # create/get internet gateway
  #####################################################
  igw=`aws --region ${AWS_REGION:?} ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=${vpc_id:?} | jq -r ".InternetGateways[0].InternetGatewayId"`
  if [ "$igw" == "null" ]; then
    igw=`aws --output json --region ${AWS_REGION:?} ec2 create-internet-gateway | jq -r ".InternetGateway.InternetGatewayId"`
    aws --region ${AWS_REGION:?} ec2 attach-internet-gateway --vpc-id ${vpc_id:?} --internet-gateway-id ${igw}
    aws --region ${AWS_REGION:?} ec2 create-tags --resources ${igw:?} --tags Key=owner,Value=${OWNER_TAG:?} Key=Name,Value=${OWNER_TAG:?}-internet-gw
  fi
  echo "igw=${igw:?}" >> ${STARTING_DIR}/bin/provider/aws/.info
  log "Internet gateway used: ${igw:?}"


  ##################################################### 
  # create elastic IP
  #####################################################  
  eip_id=`aws --region ${AWS_REGION:?} ec2 allocate-address --domain vpc | jq -r ".AllocationId"`
  echo "eip_id=${eip_id:?}" >> ${STARTING_DIR}/bin/provider/aws/.info
  aws --region ${AWS_REGION:?} ec2 create-tags --resources ${eip_id:?} --tags Key=owner,Value=${OWNER_TAG:?} Key=Name,Value=${OWNER_TAG:?}-eip
  eip_public_ip=`aws ec2 describe-addresses --allocation-ids ${eip_id:?} | jq -r ".Addresses[0].PublicIp"`
  echo "eip_public_ip=${eip_public_ip:?}" >> ${STARTING_DIR}/bin/provider/aws/.info
 
  ##################################################### 
  # create route table
  #####################################################
  rtb=`aws --output json --region ${AWS_REGION:?} ec2 create-route-table --vpc-id ${vpc_id:?} | jq -r ".RouteTable.RouteTableId"`
  aws --region ${AWS_REGION:?} ec2 create-route --route-table-id ${rtb:?} --destination-cidr-block 0.0.0.0/0 --gateway-id ${igw:?}
  aws --region ${AWS_REGION:?} ec2 associate-route-table  --subnet-id ${subnet_id:?} --route-table-id ${rtb:?}
  aws --region ${AWS_REGION:?} ec2 create-tags --resources ${rtb:?} --tags Key=owner,Value=${OWNER_TAG:?} Key=Name,Value=${OWNER_TAG:?}-route-table
  echo "rtb=${rtb:?}" >> ${STARTING_DIR}/bin/provider/aws/.info
  log "Route table used: ${rtb:?}"
 
  ##################################################### 
  # create PEM file
  #####################################################
  aws --region ${AWS_REGION:?} ec2 create-key-pair --key-name ${OWNER_TAG:?}-key-file --query 'KeyMaterial' --output text > ${STARTING_DIR}/bin/provider/aws/${OWNER_TAG:?}-key-file.pem
  chmod 400  ${STARTING_DIR}/bin/provider/aws/${OWNER_TAG:?}-key-file.pem
  echo "KEY_FILENAME=${OWNER_TAG:?}-key-file" >> ${STARTING_DIR}/bin/provider/aws/.info
  echo "KEY_FILE_PATH=${STARTING_DIR}/provider/aws/" >> ${STARTING_DIR}/bin/provider/aws/.info
  export KEY_FILENAME=${OWNER_TAG:?}-key-file
  export KEY_FILE_PATH=${STARTING_DIR}/bin/provider/aws/

  #####################################################
  # create Security Group
  #####################################################
  sg=`aws --output json --region ${AWS_REGION:?} ec2 create-security-group --group-name ${OWNER_TAG:?}-security-group --description "Security group" --vpc-id ${vpc_id:?} | jq -r ".GroupId"`
  aws --region ${AWS_REGION:?} ec2 authorize-security-group-ingress --group-id ${sg:?} --protocol all --port 0-65535 --source-group ${sg:?}
  #  need to add a port 22 access here...
  #  this next one might need to be removed...  its sets the ip allowed to the public ip address of the host running this code.  (jumpbox).
  # orig version
  aws --region ${AWS_REGION:?} ec2 authorize-security-group-ingress --group-id ${sg:?} --protocol tcp --port 0-65535 --cidr `curl -s ipinfo.io/ip`/32
  # added this to map to my home ip address and not the jumpbox server
  #aws --region ${AWS_REGION:?} ec2 authorize-security-group-ingress --group-id ${sg:?} --protocol all --port 0-65535 --cidr ${MY_HOME_IP:?}
  # add the elastic ip address public IP
  aws --region ${AWS_REGION:?} ec2 authorize-security-group-ingress --group-id ${sg:?} --protocol tcp --port 0-65535 --cidr ${eip_public_ip:?}/32
  
  aws --region ${AWS_REGION:?} ec2 create-tags --resources ${sg:?} --tags Key=owner,Value=${OWNER_TAG:?} Key=Name,Value=${OWNER_TAG:?}-security-group
  echo "sg=${sg:?}" >> ${STARTING_DIR}/bin/provider/aws/.info
  log "New Security Group in ${AWS_REGION:?} created: ${OWNER_TAG:?}-security-group, ${sg:?}"


}
