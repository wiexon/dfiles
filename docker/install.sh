#!/bin/bash
set -e

echo "installing Docker"

docker_install_dnf(){
  sudo dnf -y update
  sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
  sudo dnf -y --allowerasing install docker-ce docker-ce-cli docker-compose-plugin
  sudo systemctl enable --now docker
  sudo docker info
}

docker_install_apt(){
  # 1. Update package lists
  sudo apt-get update

  # 2. Install prerequisites
  sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release

  # 3. Add Docker's official GPG key
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

  # 4. Set up the stable repository

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  # 5. Update package lists again
  sudo apt-get update

  # 6. Install Docker Engine, CLI, containerd, and Docker Compose
  sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

  sudo systemctl enable --now docker
  sudo docker info
}

docker_compose_install_dnf(){
  echo "Installing docker compose"
  # Getting the docker compose lates version
  COMPOSE_VER=$(sudo curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)

  # Installing the docker compose file
  sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

  # Setting up the docker compse file permission
  sudo chmod +x /usr/local/bin/docker-compose

  # Creating docker compose shortcut
  sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

  # Checking the docker compose version
  docker-compose --version
}

if [[ $(command -v systemctl) ]]; then

  if [[ $(command -v dnf) ]]; then
    echo "Repository type: DNF"
    OS_ID=$(grep ^ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')
    if [[ -n $OS_ID ]]; then
      echo "OS ID: $OS_ID"
      docker_install_dnf
      docker_compose_install_dnf
    fi
  elif [[ $(command -v apt) ]]; then
    echo "Repository type: APT"
    OS_ID=$(grep ^ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')
    if [[ -n $OS_ID ]]; then
      echo "OS ID: $OS_ID"
      docker_install_apt
      docker_compose_install_dnf
    fi
  elif [[ $(command -v apk) ]]; then
    echo "Repository type: APK"
    OS_ID=$(cat /etc/alpine-release)
    if [[ -n $OS_ID ]]; then
      echo "OS ID: $OS_ID"
      echo "Docker is not implemented for APK repo manager"
    fi
  else
    echo "Repository type not found."
    exit 1
  fi

else
  echo "Systemctl is not available."
fi