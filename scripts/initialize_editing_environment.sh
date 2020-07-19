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
## No validation is performed on that name so make sure 
## that it does not contain spaces or special characters
## Stick to letters, number and underscores.
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


# create shared directories
#
SHARED_API_DIR_HOST_WSL="${dir_name}/api"
mkdir -pv ${SHARED_API_DIR_HOST_WSL}

# convert to DOSish version for windows docker
#
SHARED_API_DIR_HOST_DOSISH=${SHARED_API_DIR_HOST_WSL//\/\\}
SHARED_API_DIR_HOST_DOSISH=${SHARED_API_DIR_HOST_DOSISH//\/mnt\//}
SHARED_API_DIR_HOST_DOSISH="${SHARED_API_DIR_HOST_DOSISH:0:1}:${SHARED_API_DIR_HOST_DOSISH:1}"
IMAGE_VERSION="1.0.0"
IMAGE_NAME="mwczapski/swagger_editor"
CONTAINER_HOSTNAME="${CONTAINER_NAME}"
CONTAINER_VOLUME_MAPPING="-v ${SHARED_API_DIR_HOST_DOSISH}:/api"
CONTAINER_MAPPED_PORTS="-p 127.0.0.1:${HOST_LISTEN_PORT}:3001/tcp"


cat <<-EOF > ./scripts/environment_configuration.variables
#!/usr/bin/env bash

SHARED_API_DIR_HOST_WSL="${SHARED_API_DIR_HOST_WSL}"
SHARED_API_DIR_HOST_DOSISH="${SHARED_API_DIR_HOST_DOSISH}"
IMAGE_VERSION="${IMAGE_VERSION}"
IMAGE_NAME="${IMAGE_NAME}"
CONTAINER_NAME="${CONTAINER_NAME}"
CONTAINER_HOSTNAME="${CONTAINER_NAME}"
CONTAINER_VOLUME_MAPPING="${CONTAINER_VOLUME_MAPPING}"
CONTAINER_MAPPED_PORTS="${CONTAINER_MAPPED_PORTS}"
HOST_LISTEN_PORT=${HOST_LISTEN_PORT}

EOF


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

echo "Created environment configuration script: ./scripts/environment_configuration.variables"
echo 
cat ./scripts/environment_configuration.variables
echo
echo "Utility scripts:"
echo

ls -c1 ./scripts/*.sh

echo
echo "To create and start the container execute the following script in WSL2 Terminal window:"
echo " ./scripts/start_editing_container.sh"
echo 
echo "----------------------------------------------------------------"
