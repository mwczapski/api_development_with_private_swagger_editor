#!/usr/bin/env bash

## ###########################################################
## 
## Create a Docker Container that hosts the Swagger Editor
## for use through a Host-based Web Browser 
## 
## Container run command is configured to instruct Docker
## to remove the container when it is stopped. 
## Since no changes are expected to be made to the resources
## inside the container which are not shared from the Host 
## (like the /api shared directory which is in reality a Host directory
## to which container has access), removing and re-creating 
## the container as needed will have no side effects.
## 
## The following command will create and start the container with 
## Container Name and related as configured during initialisation
## and persisted in ./scripts/environment_configuration.variables
##
## --------------------------------
## The MIT License (MIT)
##
## Copyright (C) 2020 Michael Czapski
##
## Rights to Docker (and related), Debian, its packages and libraries, and 3rd party packages and libraries, 
## belong to their respective owners.
##
## ###########################################################

# make sure we are running from the right place
declare dir_name=${PWD}
declare base_dir_name=${dir_name##*/}
# echo "${base_dir_name}"

[[ "${base_dir_name}" == "scripts" ]] && { 
  echo "This script must not be run with the current working directory being the 'scripts' directory"
  echo "Current directory is '${dir_name}'"
  echo "Should it be '${dir_name//\/scripts/}'?"
  exit;
}

[[ -f ./scripts/environment_configuration.variables ]] || {
  echo "Cannot locate ./scripts/environment_configuration.variables configuration file"
  echo "Script cannot prceed - execute ./scripts/initialize_editing_environment.sh to prepare this file"
  exit;
}


source ./scripts/environment_configuration.variables

# make sure the container is not already in existence (whether running or stopped)
#
docker container ls -a | grep "${CONTAINER_NAME}" 2>/dev/null 1>/dev/null && {
  echo "Aborting script execution - Docker Container '${CONTAINER_NAME}' already exists and is runnning"
  exit;
}

# create shared directories
#
mkdir -pv ${SHARED_API_DIR_HOST_WSL}

# create and start the container
#
docker.exe run \
    --name ${CONTAINER_NAME} \
    --hostname ${CONTAINER_HOSTNAME} \
    ${CONTAINER_VOLUME_MAPPING} \
    ${CONTAINER_MAPPED_PORTS} \
    --detach \
    --interactive \
    --rm \
    --tty \
        ${IMAGE_NAME}:${IMAGE_VERSION}

docker container ls | grep "${CONTAINER_NAME}" 1>/dev/null || {
  echo "Failed to create container '${CONTAINER_NAME}' - please investigate the reasons"
  exit;
}

# update Host listening port in index.html in the container, if necessary
#
[[ "${HOST_LISTEN_PORT}" != "3001" ]] && docker exec -it "${CONTAINER_NAME}" sed -i "s|localhost:3001|localhost:${HOST_LISTEN_PORT}|" /swagger_tools/swagger-editor/index.html

# notify about container creation
#
docker container ls | grep "${CONTAINER_NAME}" 1>/dev/null && {
  echo
  echo "----------------------------------------------------------"
  echo "Container '${CONTAINER_NAME}' created"
} || {
  echo "Failed to update container '${CONTAINER_NAME}' - please investigate"
  exit;
}

cat <<-EOF > ./scripts/stop_and_delete_editing_container.sh
#!/usr/bin/env bash

docker container stop ${CONTAINER_NAME}
EOF
chmod u+x ./scripts/stop_and_delete_editing_container.sh

echo
echo "Host URL to run the Swagger Editor is 'http://localhost:${HOST_LISTEN_PORT}'"
echo
echo "To run the Swagger Editor in a Host's Chrome Web Browser, execute from the WSL Terminal window:"
echo " ./scripts/swagger_editor_in_chrome_on_host.sh"
echo
echo "To run the Swagger Editor in a Host's default Web Browser, execute from the WSL Terminal window:"
echo " ./scripts/swagger_editor_in_browser_on_host.sh"
echo
echo "To access container's shell, execute from the WSL Terminal window:"
echo " ./scripts/shell_in_container.sh"
echo
echo "To stop and remove the container, execute from the WSL Terminal window:"
echo " ./scripts/stop_and_delete_editing_container.sh"
echo "----------------------------------------------------------"
echo
