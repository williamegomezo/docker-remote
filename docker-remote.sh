# DOCKER REMOTE
{

docker-remote_custom_echo() {
  command printf %s\\n "$*" 2>/dev/null
}

docker-remote_clean_image_tag_name() {
  local IMAGE_TAG_NAME
  IMAGE_TAG_NAME="${1-}"
  shift
  local CLEAN_IMAGE_TAG_NAME
  CLEAN_IMAGE_TAG_NAME=${IMAGE_TAG_NAME//_/-}
  CLEAN_IMAGE_TAG_NAME=${CLEAN_IMAGE_TAG_NAME//[?! \/]/-}
  CLEAN_IMAGE_TAG_NAME=${CLEAN_IMAGE_TAG_NAME//[^a-zA-Z0-9\-]/}
  CLEAN_IMAGE_TAG_NAME=`echo $CLEAN_IMAGE_TAG_NAME | tr A-Z a-z`
  docker-remote_custom_echo $CLEAN_IMAGE_TAG_NAME
}

docker-remote_error() {
  >&2 docker-remote --help
  return 127
}

docker-remote_check_remote_user() {
  if ! groups | grep "\<sudo\>" &> /dev/null; then
    echo "Remove user must have sudo privileges"
  fi
}

docker-remote_setup_remote() {
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
  sudo apt-get update
  sudo apt-get install -y docker-ce
  sudo systemctl start docker
  sudo systemctl enable docker
  sudo groupadd docker
  sudo usermod -aG docker ${USER}
}

docker-remote() {
  if [ $# -lt 1 ]; then
    docker-remote --help
    return
  fi

  local i
  for i in "$@"
  do
    case $i in
      '-h'|'help'|'--help')

        DOCKER_REMOTE_VERSION="$(docker-remote --version)"
        docker-remote_custom_echo
        docker-remote_custom_echo "Docker Remote (v${DOCKER_REMOTE_VERSION})"
        docker-remote_custom_echo
        docker-remote_custom_echo 'Usage:'
        docker-remote_custom_echo '  docker-remote --help                                                                   Show this message'
        docker-remote_custom_echo '  docker-remote setup-remote SSH_CONNECTION                                              Setup docker in a remote server. This requires that the user in SSH_CONNECTION be set as sudoer.'
        docker-remote_custom_echo '  docker-remote push SSH_CONNECTION NAME[:TAG]                                           Push an image to a server'
        docker-remote_custom_echo '  docker-remote run SSH_CONNECTION [OPTIONS] IMAGE[:TAG|@DIGEST] [COMMAND] [ARG...]      Run an image to a server. Keeps same structure that docker run cli command after SSH_CONNECTION'
        docker-remote_custom_echo
        docker-remote_custom_echo 'Note:'
        docker-remote_custom_echo '  to remove, delete, or uninstall docker-remote just remove the `$DOCKER_REMOTE_DIR` folder (usually `~/.docker-remote`)'
        docker-remote_custom_echo
        return 0;
      ;;
    esac
  done

  local COMMAND
  COMMAND="${1-}"
  shift

  case $COMMAND in
    "setup-remote")
      if [ $# -lt 1 ]; then
        docker-remote_custom_echo 'SSH connection was not provided'
        docker-remote_error
      fi

      local SSH_CONNECTION
      SSH_CONNECTION=$1

      ssh $SSH_CONNECTION "$(typeset -f docker-remote_check_remote_user); docker-remote_check_remote_user" 
      ssh $SSH_CONNECTION "$(typeset -f docker-remote_setup_remote); docker-remote_setup_remote" 
    ;;
    "push")
      if [ $# -lt 1 ]; then
        docker-remote_custom_echo 'SSH connection was not provided'
        docker-remote_error
      fi
      if [ $# -lt 2 ]; then
        docker-remote_custom_echo 'Image tag was not provided'
        docker-remote_error
      fi

      local SSH_CONNECTION
      SSH_CONNECTION=$1
      shift

      local IMAGE_TAG_NAME
      IMAGE_TAG_NAME=$1

      local IMAGE_ID
      local IMAGE_SAVE_LOCATION
      IMAGE_ID=$(docker images --filter=reference=$IMAGE_TAG_NAME --format {{.ID}})
      mkdir -p $DOCKER_REMOTE_DIR/images
      IMAGE_SAVE_LOCATION="$DOCKER_REMOTE_DIR/images/$IMAGE_ID.tar.gz"
      docker-remote_custom_echo "Saving image as compressed file in $IMAGE_SAVE_LOCATION" 
      if [ ! -f "$IMAGE_SAVE_LOCATION" ]
      then
        docker save $IMAGE_ID | gzip > $IMAGE_SAVE_LOCATION; # TODO: Split in chunks
      else
        docker-remote_custom_echo "Image already saved in $IMAGE_SAVE_LOCATION. Using this file." 
      fi 

      local REMOTE_DIR
      REMOTE_DIR="~/.docker-remote/images"
      local REMOTE_IMAGE_LOCATION
      REMOTE_IMAGE_LOCATION="$REMOTE_DIR/$IMAGE_ID.tar.gz"
      docker-remote_custom_echo "Pushing image ($IMAGE_SAVE_LOCATION) to $SSH_CONNECTION"
      # TODO: Only push if remote checksum is different
      ssh -oStrictHostKeyChecking=no $SSH_CONNECTION "mkdir -p $REMOTE_DIR"
      scp $IMAGE_SAVE_LOCATION $SSH_CONNECTION:$REMOTE_IMAGE_LOCATION

      docker-remote_custom_echo "Loading image ($REMOTE_IMAGE_LOCATION) in $SSH_CONNECTION"
      ssh -oStrictHostKeyChecking=no $SSH_CONNECTION "gunzip -c $REMOTE_IMAGE_LOCATION | docker load"
      ssh -oStrictHostKeyChecking=no $SSH_CONNECTION "docker tag $IMAGE_ID $IMAGE_TAG_NAME; echo 'Remote images:'; docker images"
    ;;
    "run")
      if [ $# -lt 1 ]; then
        docker-remote_custom_echo 'SSH connection was not provided'
        docker-remote_error
      fi

      local SSH_CONNECTION
      SSH_CONNECTION=$1
      shift

      docker-remote_custom_echo "Running image on remote. Executing in remote: docker run $@"
      ssh -oStrictHostKeyChecking=no $SSH_CONNECTION "docker run $@"
    ;;
    "--version" | "-v")
      docker-remote_custom_echo '1.0.0'
    ;;
    *)
      >&2 docker-remote --help
      return 127
    ;;
  esac
}

} # this ensures the entire script is downloaded #
