#!/usr/bin/env bash

{ # this ensures the entire script is downloaded #

latest_version() {
  echo "v1.0.0"
}

install_dir() {
  [ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.docker-remote" || printf %s "${XDG_CONFIG_HOME}/docker-remote"
}

#
# Outputs the location of files
#
get_source() {
  local DOCKER_REMOTE_GITHUB_REPO
  DOCKER_REMOTE_GITHUB_REPO="${DOCKER_REMOTE_GITHUB_REPO:-williamegomezo/docker-remote}"
  local DOCKER_REMOTE_VERSION
  DOCKER_REMOTE_VERSION="${DOCKER_REMOTE_INSTALL_VERSION:-$(latest_version)}"
  local FILE_ID
  FILE_ID="$1"
  
  if [ "_$FILE_ID" = "_script-bash-completion" ]; then
    SOURCE_URL="https://raw.githubusercontent.com/${DOCKER_REMOTE_GITHUB_REPO}/${DOCKER_REMOTE_VERSION}/bash_completion"
  elif [ "_$FILE_ID" = "_script" ]; then
    SOURCE_URL="https://raw.githubusercontent.com/${DOCKER_REMOTE_GITHUB_REPO}/${DOCKER_REMOTE_VERSION}/docker-remote.sh"
  fi

  echo "$SOURCE_URL"
}

profile_is_bash_or_zsh() {
  local TEST_PROFILE
  TEST_PROFILE="${1-}"
  case "${TEST_PROFILE-}" in
    *"/.bashrc" | *"/.bash_profile" | *"/.zshrc")
      return
    ;;
    *)
      return 1
    ;;
  esac
}

has_dependency() {
  type "$1" > /dev/null 2>&1
}


file_download() {
  if has_dependency "curl"; then
    curl --compressed -q "$@"
  elif has_dependency "wget"; then
    # Emulate curl with wget
    ARGS=$(echo "$*" | command sed -e 's/--progress-bar /--progress=bar /' \
                            -e 's/-L //' \
                            -e 's/--compressed //' \
                            -e 's/-I /--server-response /' \
                            -e 's/-s /-q /' \
                            -e 's/-o /-O /' \
                            -e 's/-C - /-c /')
    # shellcheck disable=SC2086
    eval wget $ARGS
  fi
}

install_docker_remote_as_script() {
  local INSTALL_DIR
  INSTALL_DIR="$(install_dir)"
  local DOCKER_REMOTE_SOURCE_LOCAL
  DOCKER_REMOTE_SOURCE_LOCAL="$(get_source script)"
  local DOCKER_REMOTE_BASH_COMPLETION_SOURCE
  DOCKER_REMOTE_BASH_COMPLETION_SOURCE="$(get_source script-bash-completion)"

  # Downloading to $INSTALL_DIR
  mkdir -p "$INSTALL_DIR"
  if [ -f "$INSTALL_DIR/docker-remote.sh" ]; then
    echo "=> docker-remote is already installed in $INSTALL_DIR, trying to update the script"
  else
    echo "=> Downloading docker-remote as script to '$INSTALL_DIR'"
  fi
  echo "Downloading $DOCKER_REMOTE_SOURCE_LOCAL in $INSTALL_DIR"
  echo "Downloading $DOCKER_REMOTE_BASH_COMPLETION_SOURCE in $INSTALL_DIR"
  file_download -s "$DOCKER_REMOTE_SOURCE_LOCAL" -o "$INSTALL_DIR/docker-remote.sh" || {
    echo >&2 "Failed to download '$DOCKER_REMOTE_SOURCE_LOCAL'"
    return 1
  } &
  file_download -s "$DOCKER_REMOTE_BASH_COMPLETION_SOURCE" -o "$INSTALL_DIR/bash_completion" || {
    echo >&2 "Failed to download '$DOCKER_REMOTE_BASH_COMPLETION_SOURCE'"
    return 2
  } &
  for job in $(jobs -p | command sort)
  do
    wait "$job" || return $?
  done
}


try_profile() {
  if [ -z "${1-}" ] || [ ! -f "${1}" ]; then
    return 1
  fi
  echo "${1}"
}

#
# Detect profile file if not specified as environment variable
# (eg: PROFILE=~/.myprofile)
# The echo'ed path is guaranteed to be an existing file
# Otherwise, an empty string is returned
#
detect_profile() {
  if [ "${PROFILE-}" = '/dev/null' ]; then
    # the user has specifically requested NOT to have docker-remote touch their profile
    return
  fi

  if [ -n "${PROFILE}" ] && [ -f "${PROFILE}" ]; then
    echo "${PROFILE}"
    return
  fi

  local DETECTED_PROFILE
  DETECTED_PROFILE=''

  if [ -n "${BASH_VERSION-}" ]; then
    if [ -f "$HOME/.bashrc" ]; then
      DETECTED_PROFILE="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      DETECTED_PROFILE="$HOME/.bash_profile"
    fi
  elif [ -n "${ZSH_VERSION-}" ]; then
    DETECTED_PROFILE="$HOME/.zshrc"
  fi

  if [ -z "$DETECTED_PROFILE" ]; then
    for EACH_PROFILE in ".profile" ".bashrc" ".bash_profile" ".zshrc"
    do
      if DETECTED_PROFILE="$(try_profile "${HOME}/${EACH_PROFILE}")"; then
        break
      fi
    done
  fi

  if [ -n "$DETECTED_PROFILE" ]; then
    echo "$DETECTED_PROFILE"
  fi
}

profile_is_bash_or_zsh() {
  local TEST_PROFILE
  TEST_PROFILE="${1-}"
  case "${TEST_PROFILE-}" in
    *"/.bashrc" | *"/.bash_profile" | *"/.zshrc")
      return
    ;;
    *)
      return 1
    ;;
  esac
}

do_install() {
  install_docker_remote_as_script

  local USER_PROFILE
  USER_PROFILE="$(detect_profile)"
  local PROFILE_INSTALL_DIR
  PROFILE_INSTALL_DIR="$(install_dir | command sed "s:^$HOME:\$HOME:")"

  SOURCE_STR="\\nexport DOCKER_REMOTE_DIR=\"${PROFILE_INSTALL_DIR}\"\\n[ -s \"\$DOCKER_REMOTE_DIR/docker-remote.sh\" ] && \\. \"\$DOCKER_REMOTE_DIR/docker-remote.sh\"  # This loads docker-remote\\n"

  # shellcheck disable=SC2016
  COMPLETION_STR='[ -s "$DOCKER_REMOTE_DIR/bash_completion" ] && \. "$DOCKER_REMOTE_DIR/bash_completion"  # This loads docker-remote bash_completion\n'
  BASH_OR_ZSH=false

  if [ -z "${USER_PROFILE-}" ] ; then
    local TRIED_PROFILE
    if [ -n "${PROFILE}" ]; then
      TRIED_PROFILE="${USER_PROFILE} (as defined in \$PROFILE), "
    fi
    echo "=> Profile not found. Tried ${TRIED_PROFILE-}~/.bashrc, ~/.bash_profile, ~/.zshrc, and ~/.profile."
    echo "=> Create one of them and run this script again"
    echo "   OR"
    echo "=> Append the following lines to the correct file yourself:"
    command printf "${SOURCE_STR}"
    echo
  else
    if profile_is_bash_or_zsh "${USER_PROFILE-}"; then
      BASH_OR_ZSH=true
    fi
    # Checking if it is already in the profile
    if ! command grep -qc '/docker-remote.sh' "$USER_PROFILE"; then
      echo "=> Appending docker-remote source string to $USER_PROFILE"
      command printf "${SOURCE_STR}" >> "$USER_PROFILE"
    else
      echo "=> docker-remote source string already in ${USER_PROFILE}"
    fi
    # shellcheck disable=SC2016
    if ${BASH_OR_ZSH} && ! command grep -qc '$DOCKER_REMOTE_DIR/bash_completion' "$USER_PROFILE"; then
      echo "=> Appending bash_completion source string to $USER_PROFILE"
      command printf "$COMPLETION_STR" >> "$USER_PROFILE"
    else
      echo "=> bash_completion source string already in ${USER_PROFILE}"
    fi
  fi
  if ${BASH_OR_ZSH} && [ -z "${USER_PROFILE-}" ] ; then
    echo "=> Please also append the following lines to the if you are using bash/zsh shell:"
    command printf "${COMPLETION_STR}"
  fi

  # Source docker-remote
  # shellcheck source=/dev/null
  \. "$(install_dir)/docker-remote.sh"

  reset_functions

  echo "=> Close and reopen your terminal to start using docker-remote or run the following to use it now:"
  command printf "${SOURCE_STR}"
  if ${BASH_OR_ZSH} ; then
    command printf "${COMPLETION_STR}"
  fi
}

#
# Unsets the various functions defined
# during the execution of the install script
#
reset_functions() {
  unset -f profile_is_bash_or_zsh detect_profile try_profile \
  install_docker_remote_as_script file_download profile_is_bash_or_zsh \
  get_source install_dir latest_version
}

[ "_$DOCKER_REMOTE_ENV" = "_testing" ] || do_install

} # this ensures the entire script is downloaded #