#syntax=docker/dockerfile:1
# see https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/reference.md
# see https://docs.docker.com/engine/reference/builder/#syntax
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-softhsm2-pkcs11-proxy

#############################################################
# build softhsmv2 + pkcs11-proxy
#############################################################
# https://hub.docker.com/_/alpine/tags?name=latest
# https://github.com/alpinelinux/docker-alpine/blob/master/Dockerfile
ARG BASE_IMAGE=alpine:latest

# https://github.com/hadolint/hadolint/wiki/DL3006 Always tag the version of an image explicitly
# hadolint ignore=DL3006
FROM ${BASE_IMAGE} AS builder

ARG BASE_LAYER_CACHE_KEY

ARG SOFTHSM_SOURCE_URL
ARG PKCS11_PROXY_SOURCE_URL

SHELL ["/bin/ash", "-euo", "pipefail", "-c"]

# https://github.com/hadolint/hadolint/wiki/DL3018 Pin versions
# hadolint ignore=DL3018
RUN --mount=type=bind,source=.shared,target=/mnt/shared <<EOF
  /mnt/shared/cmd/alpine-install-os-updates.sh

  echo "#################################################"
  echo "Installing required dev packages..."
  echo "#################################################"
  apk add --no-cache \
     `# required by curl:` \
     ca-certificates \
     curl \
     `# required for autogen.sh:` \
     autoconf \
     automake \
     libtool \
     `# required for configure/make:` \
     build-base \
     openssl-dev \
     `# additional packages required by softhsm:` \
     sqlite \
     sqlite-dev \
     `# additional packages required by pkcs11-proxy:` \
     bash \
     cmake \
     libseccomp-dev

EOF

# https://github.com/hadolint/hadolint/wiki/DL3003 Use WORKDIR to switch to a directory
# hadolint ignore=DL3003
RUN <<EOF
  echo "#################################################"
  echo "Building softhsm2 ..."
  echo "#################################################"
  echo "Downloading [$SOFTHSM_SOURCE_URL]..."
  curl -fsS "$SOFTHSM_SOURCE_URL" | tar xvz
  mv SoftHSMv2-* softhsm2
  cd softhsm2 || exit 1
  sh ./autogen.sh
  ./configure --with-objectstore-backend-db --disable-dependency-tracking
  make
  make install
  softhsm2-util --version

EOF


# https://github.com/hadolint/hadolint/wiki/DL3003 Use WORKDIR to switch to a directory
# hadolint ignore=DL3003
RUN <<EOF
  echo "#################################################"
  echo "Buildding pkcs11-proxy ..."
  echo "#################################################"
  curl -fsS "$PKCS11_PROXY_SOURCE_URL" | tar xvz
  mv pkcs11-proxy-* pkcs11-proxy
  cd pkcs11-proxy || exit 1
  cmake .
  make
  make install

EOF


#############################################################
# build final image
#############################################################

# https://github.com/hadolint/hadolint/wiki/DL3006 Always tag the version of an image explicitly
# hadolint ignore=DL3006
FROM ${BASE_IMAGE}

LABEL maintainer="Vegard IT GmbH (vegardit.com)"

# https://github.com/hadolint/hadolint/wiki/DL3002 Last USER should not be root
# hadolint ignore=DL3002
USER root

ARG BASE_LAYER_CACHE_KEY

# https://github.com/hadolint/hadolint/wiki/DL3018 Pin versions
# hadolint ignore=DL3018
RUN --mount=type=bind,source=.shared,target=/mnt/shared <<EOF
  /mnt/shared/cmd/alpine-install-os-updates.sh

  echo "#################################################"
  echo "Installing required packages..."
  echo "#################################################"
  apk add --no-cache \
     bash \
     libstdc++ \
     libssl3 \
     opensc `# contains pkcs11-tool` \
     sqlite-libs \
     tini

  /mnt/shared/cmd/alpine-cleanup.sh

EOF

# copy softhsm2
COPY --from=builder /etc/softhsm* /etc/
COPY --from=builder /usr/local/bin/softhsm* /usr/local/bin/
COPY --from=builder /usr/local/lib/softhsm/libsofthsm2.so /usr/local/lib/softhsm/libsofthsm2.so
COPY --from=builder /usr/local/share/man/man1/softhsm* /usr/local/share/man/man1/
COPY --from=builder /usr/local/share/man/man5/softhsm* /usr/local/share/man/man5/

# copy pkcs11-proxy
COPY --from=builder /usr/local/bin/pkcs11-* /usr/local/bin/
COPY --from=builder /usr/local/lib/libpkcs11-proxy* /usr/local/lib/

COPY image/*.sh /opt
COPY image/test.* /opt
COPY .shared/lib/bash-init.sh /opt/bash-init.sh

# Default configuration: can be overridden at the docker command line
ENV \
  INIT_SH_FILE='/opt/init-token.sh' \
  #
  TOKEN_AUTO_INIT=1 \
  TOKEN_LABEL="Test Token" \
  TOKEN_USER_PIN="1234" \
  TOKEN_USER_PIN_FILE="" \
  TOKEN_SO_PIN="5678" \
  TOKEN_SO_PIN_FILE="" \
  TOKEN_IMPORT_TEST_DATA=0 \
  #
  SOFTHSM_STORAGE=file \
  #
  PKCS11_DAEMON_SOCKET="tls://0.0.0.0:2345" \
  PKCS11_PROXY_TLS_PSK_FILE="/opt/test.tls.psk"

ARG BUILD_DATE
ARG GIT_BRANCH
ARG GIT_COMMIT_HASH
ARG GIT_COMMIT_DATE
ARG GIT_REPO_URL

LABEL \
  org.label-schema.schema-version="1.0" \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.vcs-ref=$GIT_COMMIT_HASH \
  org.label-schema.vcs-url=$GIT_REPO_URL

RUN <<EOF
  set -eu
  #shellcheck disable=SC3037  # In POSIX sh, echo flags are undefined.
  echo -e "\
GIT_REPO:    $GIT_REPO_URL\n\
GIT_BRANCH:  $GIT_BRANCH\n\
GIT_COMMIT:  $GIT_COMMIT_HASH @ $GIT_COMMIT_DATE\n\
IMAGE_BUILD: $BUILD_DATE" >/opt/build_info
  cat /opt/build_info

  mkdir -p /var/lib/softhsm/tokens/
  chmod -R 700 /var/lib/softhsm
  echo "alias pkcs11-tool='pkcs11-tool --module /usr/local/lib/softhsm/libsofthsm2.so'" >> /root/.bashrc

EOF

EXPOSE 2345

VOLUME "/var/lib/softhsm/"

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["/bin/bash", "/opt/run.sh"]
