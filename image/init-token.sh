#!/usr/bin/env bash
#
# Copyright 2021 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#
# https://github.com/vegardit/docker-softhsm2-pkcs11-proxy

# shellcheck disable=SC1091  # Not following: /opt/bash-init.sh was not specified as input
type -t log >/dev/null || source /opt/bash-init.sh

shopt -s expand_aliases

alias pkcs11-tool='pkcs11-tool --module /usr/local/lib/softhsm/libsofthsm2.so'


if [[ -n ${TOKEN_SO_PIN_FILE:-} && -e $TOKEN_SO_PIN_FILE ]]; then
   log INFO "Loading Admin Pin from [$TOKEN_SO_PIN_FILE]..."
   TOKEN_SO_PIN=$(head -n 1 "$TOKEN_SO_PIN_FILE")
fi

if [[ -n ${TOKEN_USER_PIN_FILE:-} && -e $TOKEN_USER_PIN_FILE ]]; then
   log INFO "Loading User Pin from [$TOKEN_USER_PIN_FILE]..."
   TOKEN_USER_PIN=$(head -n 1 "$TOKEN_USER_PIN_FILE")
fi


# check if slot 0 is initialized already
if pkcs11-tool --test --token-label "$TOKEN_LABEL" >/dev/null 2>&1; then
   if [[ -n ${TOKEN_SO_PIN:-} ]]; then
      log INFO "Testing admin pin of token [$TOKEN_LABEL]..."
      pkcs11-tool --test --token-label "$TOKEN_LABEL" --so-pin "$TOKEN_SO_PIN"
   fi

   if [[ -n ${TOKEN_USER_PIN:-} ]]; then
      log INFO "Testing user pin of token [$TOKEN_LABEL]..."
      pkcs11-tool --test --token-label "$TOKEN_LABEL" --pin "$TOKEN_USER_PIN"
   fi

elif [[ ${TOKEN_AUTO_CREATE:-1} == 1 ]]; then
   log INFO "Initializing token [$TOKEN_LABEL]..."
   softhsm2-util \
      --init-token \
      --free \
      --label "$TOKEN_LABEL" \
      --pin "$TOKEN_USER_PIN" \
      --so-pin "$TOKEN_SO_PIN"

   if [[ ${TOKEN_IMPORT_TEST_DATA:-1} == 1 ]]; then
      log INFO "Importing Test Private Key into token [$TOKEN_LABEL]..."
      pkcs11-tool --login --token-label "$TOKEN_LABEL" --pin "$TOKEN_USER_PIN" --write-object /opt/test.pem.key --type privkey --id 1 --label "Test Private Key"

      log INFO "Importing Test Cert into token [$TOKEN_LABEL]..."
      pkcs11-tool --login --token-label "$TOKEN_LABEL" --pin "$TOKEN_USER_PIN" --write-object /opt/test.pem.crt --type cert --id 1 --label "Test Certificate"
   fi
fi
