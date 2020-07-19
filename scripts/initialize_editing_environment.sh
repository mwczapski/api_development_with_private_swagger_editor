#!/usr/bin/env bash

## ###########################################################
## 
## Create a Docker Container that hosts the Swagger Editor
## for use through a Host-based Web Browser 
## 
## 
## By default, the name of the container will be the same 
## as the name of the host directory from which the script is invoked. 
## 
## No validaiton is performed on that name so make sure 
## that it does not ocntaine spaces ro special characters
## Stick to letters, number and underscores.
## 
## Container run command is configured to instruct Docker
## to remove the container when it is stopped. 
## Since no changes are expected to be made to the resources
## inside the container which are not shared from the Host 
## (like the /api shared directory which is in reality a Host directory
## to which container has access), removing and re-creating 
## the container as needed will have no side effects.
## 
## The following command will create the container with 
## the Container name as given by the CONTAINER_NAME command line variable -> "aa"
## the host listening port as given by the HOST_LISTEN_PORT command line variable -> "2345"
##
## CONTAINER_NAME=aa HOST_LISTEN_PORT=2345 ./scripts/initialize_editing_environment.sh
## 
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

# review this assignements and change as required
#
declare HOST_LISTEN_PORT=${HOST_LISTEN_PORT:-3101}
declare CONTAINER_NAME=${CONTAINER_NAME:-${base_dir_name}}

# confirm settings and allow backout
#
echo "All project artefacts will be created in directory hierarchy starting with '${base_dir_name}'"
echo "Docker Container Name will be '${CONTAINER_NAME}'"
echo "Host URL to access the Swagger Editor will be 'http://localhost:${HOST_LISTEN_PORT}'"
echo
read -p "Accept location, container name and port (N/y) [N] ? " ynResp
echo
ynResp=${ynResp:0:1}
ynResp=${ynResp^^}
ynResp="${ynResp:-N}"
[[ "${ynResp}" == "N" ]] && {
  echo "Aborting script execution on user request"
  exit;
}
[[ "${ynResp}" != "Y" ]] && {
  echo "Aborting script execution due to unacceptable response '${ynResp}'"
  exit;
}

# make sure the container is not already in existence (whether running or stopped)
#
docker container ls -a | grep "${CONTAINER_NAME}" 2>/dev/null 1>/dev/null && {
  echo "Aborting script execution - Docker Container '${CONTAINER_NAME}' already exists and is runnning"
  exit;
}

# create shared directories
#
SHARED_API_DIR_HOST_WSL="${dir_name}/api"

# convert to DOSish version for windows docker
#
SHARED_API_DIR_HOST_DOSISH=${SHARED_API_DIR_HOST_WSL//\/\\}
SHARED_API_DIR_HOST_DOSISH=${SHARED_API_DIR_HOST_DOSISH//\/mnt\//}
SHARED_API_DIR_HOST_DOSISH="${SHARED_API_DIR_HOST_DOSISH:0:1}:${SHARED_API_DIR_HOST_DOSISH:1}"

# echo ${SHARED_API_DIR_HOST_DOSISH}

mkdir -pv ${SHARED_API_DIR_HOST_WSL}

# create initial openapi.yaml if it does not already exist
#
[[ -f ${SHARED_API_DIR_HOST_WSL}/openapi.yaml ]] || \
cat <<-'EOF' > ${SHARED_API_DIR_HOST_WSL}/openapi.yaml
openapi: "3.0.1"
info:
  title: Weather API
  description: |
    This API is a __test__ API for validation of local swagger editor
    deployment and configuration
  version: 1.0.0
servers:
  - url: 'http://localhost:3103/'
tags:
  - name: Weather
    description: Weather, and so on
paths:
  /weather:
    get:
      tags:
        - Weather
      description: |
        This endpoint will tell whether weather is __good__ or _bad_.
      operationId: status
      responses:
        '200':
          description: Good weather
          content: {}
        '500':
          description: Unexpected Error
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/response_500'
components:
  schemas:
    response_500:
      type: object
      properties:
        message:
          type: string
EOF

# create and start Swagger Editor Docker Container
#
IMAGE_VERSION="1.0.0"
IMAGE_NAME="mwczapski/swagger_editor"
CONTAINER_HOSTNAME="${CONTAINER_NAME}"
CONTAINER_VOLUME_MAPPING=" -v ${SHARED_API_DIR_HOST_DOSISH}:/api"
CONTAINER_MAPPED_PORTS=" -p 127.0.0.1:${HOST_LISTEN_PORT}:3001/tcp "

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

# create 'run shell in the container' script
#
cat <<-EOF > ./scripts/shell_in_container.sh
#!/usr/bin/env bash

## This script is auto-generated at container creation
## Edits will not be preserved accross container creation events
##
docker container exec -it ${CONTAINER_NAME} bash -l

EOF
chmod u+x ./scripts/shell_in_container.sh

# create run the default web browser with the url on Windows script
#
cat <<-EOF > ./scripts/swagger_editor_in_browser_on_host.sh

## This script is auto-generated at container creation
## Edits will not be preserved accross container creation events
##
cmd.exe /c start http://localhost:${HOST_LISTEN_PORT}

EOF
chmod u+x ./scripts/swagger_editor_in_browser_on_host.sh

# create run the Chrome web browser with the url on Windows script
# Use Chrome. 
# Firefox does not work even though it appears to.
# Changes made in Firefox can't be saved to the shared Host directory
# which makes it pretty useless for anything except looking at the  
# specification and executing tests (if backend servers are running).
#
cat <<-EOF > ./scripts/swagger_editor_in_chrome_on_host.sh

## This script is auto-generated at container creation
## Edits will not be preserved accross container creation events
##
cmd.exe /c "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" -new-window http://localhost:${HOST_LISTEN_PORT} 2>/dev/null &

EOF
chmod u+x ./scripts/swagger_editor_in_chrome_on_host.sh

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
echo " docker container stop ${CONTAINER_NAME}"
echo "----------------------------------------------------------"
echo
