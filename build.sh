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

# Get correct Python version per distro (max 3.13 to avoid Ansible compatibility issues)
get_python_version() {
  case "$1" in
    ubuntu2004|ubuntu2204|ubuntu2404|ubuntu)
      # Ubuntu versions: use system Python or fallback to available version
      echo "system"  # Will use system Python (3.8 for 20.04, 3.10 for 22.04, 3.12 for 24.04)
      ;;
    debian11|debian12)
      # Debian 11/12: use system Python (3.13 not available in repos)
      echo "system"
      ;;
    debian13|debian)
      # Debian 13+: try 3.13, fallback to system
      echo "3.13"
      ;;
    rockylinux8)
      # Rocky Linux 8: use system Python (3.13 not available)
      echo "system"
      ;;
    rockylinux9|rockylinux)
      # Rocky Linux 9+: try 3.13, fallback to system
      echo "3.13"
      ;;
    alpine3.20|alpine3.21|alpine3.22|alpine3)
      # Alpine versions: use system Python (3.13 may not be available in all versions)
      echo "system"
      ;;
    *)
      echo "system"
      ;;
  esac
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
  
  # Set Python version per distro (max 3.13)
  # Use PYTHON_VERSION from environment if set, otherwise use get_python_version function
  python_version=${PYTHON_VERSION:-$(get_python_version "$tag")}

  # Create pip requirements file dynamically
  echo "📄 Writing requirements/pip.txt"
  {
    echo "$ansible_version"
    cat requirements/pip-common.txt
  } > requirements/pip.txt

  echo "--- requirements/pip.txt for $tag ---"
  cat requirements/pip.txt
  echo "------------------------------------"
  echo "🐍 Python version for $tag: $python_version"

  # Determine platforms based on build type and image age
  # For local builds (no --push), use native platform only
  # For pushes, use multi-platform builds
  if [[ -n "$PUSH_FLAG" ]]; then
    # Multi-platform build for Docker Hub
    case "$tag" in
      rockylinux8|ubuntu2004|debian11)
        platforms="linux/amd64"
        echo "⚠️  Building $tag for amd64 only (legacy image)"
        ;;
      *)
        platforms="linux/amd64,linux/arm64"
        echo "✅ Building $tag for amd64 and arm64 (multi-platform)"
        ;;
    esac
  else
    # Local build: use native platform only
    native_arch=$(uname -m)
    case "$native_arch" in
      x86_64)
        platforms="linux/amd64"
        ;;
      arm64|aarch64)
        platforms="linux/arm64"
        ;;
      *)
        platforms="linux/amd64"
        echo "⚠️  Unknown architecture $native_arch, defaulting to amd64"
        ;;
    esac
    echo "🔧 Local build: Building $tag for native platform ($platforms)"
  fi

  # Build image for determined platforms
  docker buildx build \
    $PUSH_FLAG \
    --platform $platforms \
    -f dockerfiles/$dockerfile \
    --build-arg BASE_IMAGE=$base_image \
    --build-arg PYTHON_VERSION=$python_version \
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
