#!/usr/bin/env bash
#
# Copyright 2021 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#
# https://github.com/vegardit/docker-softhsm2-pkcs11-proxy

source /opt/bash-init.sh

#################################################
# print header
#################################################
cat <<'EOF'
############################
#  SoftHSMv2 PKCS11 Proxy  #
############################

EOF

cat /opt/build_info
echo

log INFO "Timezone is $(date +"%Z %z")"
log INFO "Hostname: $(hostname -f)"
log INFO "IP Addresses: "
awk '/32 host/ { if(uniq[ip]++ && ip != "127.0.0.1") print " - " ip } {ip=$2}' /proc/net/fib_trie

log INFO "Configuring SoftHSM storage type [$SOFTHSM_STORAGE]..."
case $SOFTHSM_STORAGE in
   file)      sed -iE 's/^objectstore.backend\s?=\s?.*/objectstore.backend = file/' /etc/softhsm2.conf ;;
   db|sqlite) sed -iE 's/^objectstore.backend\s?=\s?.*/objectstore.backend = db/'   /etc/softhsm2.conf ;;
   *)         log ERROR "Unsupported SoftHSM storage type [$SOFTHSM_STORAGE]"; exit 1 ;;
esac


#################################################
# load custom init script if specified
#################################################
if [[ -f $INIT_SH_FILE ]]; then
   log INFO "Loading [$INIT_SH_FILE]..."
   source "$INIT_SH_FILE"
fi

log INFO "Starting pkcs11-daemon..."
/usr/local/bin/pkcs11-daemon /usr/local/lib/softhsm/libsofthsm2.so
