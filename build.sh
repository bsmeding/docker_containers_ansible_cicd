#!/bin/bash

set -euo pipefail

# Map: tag -> Dockerfile + base image
declare -A builds=(
  [ubuntu2004]="ubuntu.Dockerfile ubuntu:20.04"
  [ubuntu2204]="ubuntu.Dockerfile ubuntu:22.04"
  [debian11]="debian.Dockerfile debian:bullseye"
  [debian12]="debian.Dockerfile debian:bookworm"
  [rockylinux8]="rocky.Dockerfile rockylinux:8"
  [rockylinux9]="rocky.Dockerfile rockylinux:9"
  [alpine3.20]="alpine.Dockerfile alpine:3.20"
  [alpine3.21]="alpine.Dockerfile alpine:3.21"
)

# Get correct Ansible version per distro version
get_ansible_version() {
  if [[ "$1" == "rockylinux8" ]]; then
    echo "ansible==4.10.0"
  elif [[ "$1" == "ubuntu2004" ]]; then
    echo "ansible==6.7.0"
  elif [[ "$1" == "debian11" || "$1" == "rockylinux9" ||  "$1" == "alpine3.17" ]]; then
    echo "ansible==8.7.0"
  else
    echo "ansible==9.5.1"
  fi
}

# Common pip packages
common_pip_packages="
cryptography
yamllint
pynautobot
pynetbox
jmespath
netaddr
pywinrm
"

# Loop through builds
for tag in "${!builds[@]}"; do
  IFS=' ' read -r dockerfile base_image <<< "${builds[$tag]}"
  echo -e "\n🔨 Building image for: $tag"
  echo "📦 Using base image: $base_image"
  echo "📄 Dockerfile: $dockerfile"

  # Set Ansible version per distro
  ansible_version=$(get_ansible_version "$tag")

  # Create pip requirements file dynamically
  echo "📄 Writing requirements/pip.txt"
  {
    echo "$ansible_version"
    echo "$common_pip_packages"
  } > requirements/pip.txt

  echo "--- requirements/pip.txt for $tag ---"
  cat requirements/pip.txt
  echo "------------------------------------"

  # Check if it is a Git push
  PUSH_FLAG=""
  if [[ "${1:-}" == "--push" ]]; then
    PUSH_FLAG="--push"
  fi

  # Build image
  docker buildx build \
    $PUSH_FLAG \
    -f dockerfiles/$dockerfile \
    --build-arg BASE_IMAGE=$base_image \
    -t bsmeding/ansible_cicd_${tag}:latest .

  echo "✅ Image built: bsmeding/ansible_cicd_${tag}:latest"
done

echo -e "\n🎉 All builds completed!"
