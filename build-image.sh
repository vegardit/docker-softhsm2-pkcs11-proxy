#!/usr/bin/env bash
#
# Copyright 2021 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#
# https://github.com/vegardit/docker-softhsm2-pkcs11-proxy

shared_lib="$(dirname $0)/.shared"
[ -e "$shared_lib" ] || curl -sSf https://raw.githubusercontent.com/vegardit/docker-shared/v1/download.sh?_=$(date +%s) | bash -s v1 "$shared_lib" || exit 1
source "$shared_lib/lib/build-image-init.sh"


#################################################
# specify target docker registry/repo
#################################################
docker_registry=${DOCKER_REGISTRY:-docker.io}
image_repo=${DOCKER_IMAGE_REPO:-vegardit/softhsm2-pkcs11-proxy}
base_image_name=${DOCKER_BASE_IMAGE:-alpine:3}
base_image_linux_flavor=${base_image_name%%:*}

app_version=${SOFTHSM_VERSION:-latest}
case $app_version in \
   latest)
      #app_version=$(curl -sSfL https://github.com/opendnssec/SoftHSMv2/releases/latest | sed -n "s/.*releases\/tag\/\([0-9]\.[0-9]\.[0-9]\)['\"].*/\1/p" | head -1)
      app_version=$(curl -sSfL https://github.com/opendnssec/SoftHSMv2/tags | sed -n "s/.*releases\/tag\/\([0-9]\.[0-9]\.[0-9]\)['\"].*/\1/p" | head -1)
      softhsm_source_url=https://codeload.github.com/opendnssec/SoftHSMv2/tar.gz/refs/tags/$app_version
      app_version_is_latest=1
     ;;
   develop)
      softhsm_source_url=https://codeload.github.com/opendnssec/SoftHSMv2/tar.gz/refs/heads/develop
     ;;
   *)
      softhsm_source_url=https://codeload.github.com/opendnssec/SoftHSMv2/tar.gz/refs/tags/$app_version
     ;;
esac
echo "app_version=$app_version"
echo "softhsm_source_url=$softhsm_source_url"


#################################################
# calculate tags
#################################################
declare -a tags=()

if [[ $app_version == develop ]]; then
   tags+=("$image_repo:develop-$base_image_linux_flavor") # :develop-alpine
   if [[ $base_image_linux_flavor == alpine ]]; then
      tags+=("$image_repo:develop") # :develop
   fi
else
   if [[ $app_version =~ ^[0-9]+\..*$ ]]; then
      tags+=("$image_repo:${app_version%%.*}.x-$base_image_linux_flavor") # :2.x-alpine
      if [[ $base_image_linux_flavor == alpine ]]; then
         tags+=("$image_repo:${app_version%%.*}.x-$base_image_linux_flavor") # :2.x
      fi
   fi

   if [[ ${app_version_is_latest:-} == 1 ]]; then
      tags+=("$image_repo:latest-$base_image_linux_flavor") # :latest-alpine
      if [[ $base_image_linux_flavor == alpine ]]; then
         tags+=("$image_repo:latest") # :latest
      fi
   fi
fi

image_name=${tags[0]}


#################################################
# build the image
#################################################
echo "Building docker image [$image_name]..."
if [[ $OSTYPE == "cygwin" || $OSTYPE == "msys" ]]; then
   project_root=$(cygpath -w "$project_root")
fi

case $base_image_name in
   alpine:*) dockerfile="alpine.Dockerfile" ;;
   debian:*) dockerfile="debian.Dockerfile" ;;
   *) echo "ERROR: Unsupported base image $base_image_name"; exit 1 ;;
esac

docker pull $base_image_name
DOCKER_BUILDKIT=1 docker build "$project_root" \
   --file "image/$dockerfile" \
   --progress=plain \
   --build-arg INSTALL_SUPPORT_TOOLS=${INSTALL_SUPPORT_TOOLS:-0} \
   `# using the current date as value for BASE_LAYER_CACHE_KEY, i.e. the base layer cache (that holds system packages with security updates) will be invalidate once per day` \
   --build-arg BASE_LAYER_CACHE_KEY=$base_layer_cache_key \
   --build-arg BASE_IMAGE=$base_image_name \
   --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
   --build-arg GIT_BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}" \
   --build-arg GIT_COMMIT_DATE="$(date -d @$(git log -1 --format='%at') --utc +'%Y-%m-%d %H:%M:%S UTC')" \
   --build-arg GIT_COMMIT_HASH="$(git rev-parse --short HEAD)" \
   --build-arg GIT_REPO_URL="$(git config --get remote.origin.url)" \
   --build-arg SOFTHSM_SOURCE_URL="$softhsm_source_url" \
   --build-arg PKCS11_PROXY_SOURCE_URL="https://codeload.github.com/scobiej/pkcs11-proxy/tar.gz/refs/heads/osx-openssl1-1" \
   `#--build-arg PKCS11_PROXY_SOURCE_URL="https://codeload.github.com/SUNET/pkcs11-proxy/tar.gz/refs/heads/master"` \
   -t $image_name \
   "$@"


#################################################
# apply tags
#################################################
for tag in ${tags[@]}; do
   docker image tag $image_name $tag
done


#################################################
# perform security audit
#################################################
bash "$shared_lib/cmd/audit-image.sh" $image_name


#################################################
# push image with tags to remote docker image registry
#################################################
if [[ "${DOCKER_PUSH:-0}" == "1" ]]; then
   for tag in ${tags[@]}; do
      docker push $docker_registry/$tag
   done
fi
