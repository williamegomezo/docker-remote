# Docker Remote [![Build Status](https://travis-ci.org/williamegomezo/docker-remote.svg?branch=master)][3] [![docker-remote version](https://img.shields.io/badge/version-v1.0.0-yellow.svg)][4] 

Docker remote is a CLI to manage everything about docker in a remote machine.

## Installing and Updating
All installation scripts are based on `nvm` installation scripts (https://github.com/nvm-sh/nvm).

### Install & Update Script

To **install** or **update** docker-remote, you should run the [install script][2]. To do that, you may either download and run the script manually, or use the following cURL or Wget command:
```sh
curl -o- https://raw.githubusercontent.com/williamegomezo/docker-remote/v1.0.0/install.sh | bash
```
```sh
wget -qO- https://raw.githubusercontent.com/williamegomezo/docker-remote/v1.0.0/install.sh | bash
```

Running either of the above commands downloads a script and runs it. The script clones the nvm repository to `~/.docker-remote`, and attempts to add the source lines from the snippet below to the correct profile file (`~/.bash_profile`, `~/.zshrc`, `~/.profile`, or `~/.bashrc`).

<a id="profile_snippet"></a>
```sh
export DOCKER_REMOTE_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.docker-remote" || printf %s "${XDG_CONFIG_HOME}/docker-remote")"
[ -s "$DOCKER_REMOTE_DIR/docker-remote.sh" ] && \. "$DOCKER_REMOTE_DIR/docker-remote.sh" # This loads docker-remote
```

### Commands

#### Help:
List all commands and instructions.

```
docker-remote --help
```

#### Setup a remote with Docker:
Install and configures a remote machine with docker. 
Prerequisites:
- Remote machine user in SSH_CONNECTION must be a sudoer.

```
docker-remote setup-remote SSH_CONNECTION
```

SSH_CONNECTION examples:
```
docker-remote setup-remote host_saved_in_ssh_config
docker-remote setup-remote user@host
```

#### Push a image using a tag name:
Push a local image to a remote machine.

```
docker-remote push SSH_CONNECTION NAME[:TAG]
```

#### Run a image remotely:
Runs docker in remote machine, after SSH_CONNECTION this command works as docker run in a local machine.

```
docker-remote run SSH_CONNECTION [OPTIONS] IMAGE[:TAG|@DIGEST] [COMMAND] [ARG...]
```

[2]: https://github.com/williamegomezo/docker-remote/blob/v1.0.0/install.sh
[3]: https://travis-ci.org/williamegomezo/docker-remote
[4]: https://github.com/williamegomezo/docker-remote/releases/tag/v1.0.0