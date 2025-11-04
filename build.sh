#!/bin/bash

set -eo pipefail

# Get build info for a tag: returns "dockerfile base_image"
get_build_info() {
  case "$1" in
    ubuntu2004) echo "ubuntu.Dockerfile ubuntu:20.04" ;;
    ubuntu2204) echo "ubuntu.Dockerfile ubuntu:22.04" ;;
    ubuntu2404) echo "ubuntu.Dockerfile ubuntu:24.04" ;;
    ubuntu) echo "ubuntu.Dockerfile ubuntu:24.04" ;;
    debian11) echo "debian.Dockerfile debian:bullseye" ;;
    debian12) echo "debian.Dockerfile debian:bookworm" ;;
    debian13) echo "debian.Dockerfile debian:trixie" ;;
    debian) echo "debian.Dockerfile debian:trixie" ;;
    rockylinux8) echo "rocky.Dockerfile rockylinux:8" ;;
    rockylinux9) echo "rocky.Dockerfile rockylinux:9" ;;
    rockylinux) echo "rocky.Dockerfile rockylinux:9" ;;
    alpine3.20) echo "alpine.Dockerfile alpine:3.20" ;;
    alpine3.21) echo "alpine.Dockerfile alpine:3.21" ;;
    alpine3.22) echo "alpine.Dockerfile alpine:3.22" ;;
    alpine3) echo "alpine.Dockerfile alpine:3.22" ;;
    *) echo "" ;;
  esac
}

# Get all available tags
get_all_tags() {
  echo "ubuntu2004 ubuntu2204 ubuntu2404 ubuntu debian11 debian12 debian13 debian rockylinux8 rockylinux9 rockylinux alpine3.20 alpine3.21 alpine3.22 alpine3"
}

# Get correct Ansible version per distro version
get_ansible_version() {
  if [[ "$1" == "rockylinux8" ]]; then
    echo "ansible==4.10.0"
  elif [[ "$1" == "ubuntu2004" ]]; then
    echo "ansible==6.7.0"
  else
    echo "ansible==8.7.0"
  fi
}

# Parse command-line arguments
BUILD_TAG=""
PUSH_FLAG=""
for arg in "$@"; do
  if [[ "$arg" == "--push" ]]; then
    PUSH_FLAG="--push"
  elif [[ "$arg" != "--push" && -z "$BUILD_TAG" ]]; then
    BUILD_TAG="$arg"
  fi
done

# Determine which tags to build
if [[ -n "${BUILD_TAG:-}" ]]; then
  # Build only the specified tag
  build_info=$(get_build_info "$BUILD_TAG")
  if [[ -z "$build_info" ]]; then
    echo "❌ Error: Unknown tag '$BUILD_TAG'"
    echo "Available tags: $(get_all_tags)"
    exit 1
  fi
  tags_to_build=("$BUILD_TAG")
else
  # Build all tags
  tags_to_build=($(get_all_tags))
fi

# Loop through builds
for tag in "${tags_to_build[@]}"; do
  IFS=' ' read -r dockerfile base_image <<< "$(get_build_info "$tag")"
  echo -e "\n🔨 Building image for: $tag"
  echo "📦 Using base image: $base_image"
  echo "📄 Dockerfile: $dockerfile"

  # Set Ansible version per distro
  ansible_version=$(get_ansible_version "$tag")

  # Create pip requirements file dynamically
  echo "📄 Writing requirements/pip.txt"
  {
    echo "$ansible_version"
    cat requirements/pip-common.txt
  } > requirements/pip.txt

  echo "--- requirements/pip.txt for $tag ---"
  cat requirements/pip.txt
  echo "------------------------------------"

  # Build image
  docker buildx build \
    $PUSH_FLAG \
    -f dockerfiles/$dockerfile \
    --build-arg BASE_IMAGE=$base_image \
    -t bsmeding/ansible_cicd_${tag}:latest .

  echo "✅ Image built: bsmeding/ansible_cicd_${tag}:latest"

  # 📝 Update Docker Hub README from README.md
  # if [[ -f README.md ]]; then
  #   echo "📤 Updating Docker Hub description for bsmeding/ansible_cicd_${tag}"
  #   docker run --rm -v "$(pwd)":/data \
  #     -e DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-}" \
  #     -e DOCKERHUB_TOKEN="${DOCKERHUB_TOKEN:-}" \
  #     peter-evans/dockerhub-description:latest \
  #     --username "${DOCKERHUB_USERNAME}" \
  #     --password "${DOCKERHUB_TOKEN}" \
  #     --repository "bsmeding/ansible_cicd_${tag}" \
  #     --readme-file /data/README.md
  # fi
done

if [[ -n "${BUILD_TAG:-}" ]]; then
  echo -e "\n🎉 Build completed: $BUILD_TAG"
else
  echo -e "\n🎉 All builds completed!"
fi
