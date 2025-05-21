# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-softhsm2-pkcs11-proxy

FROM alpine:latest

# install pkcs11-tool
RUN apk add --no-cache opensc openssl

# install libpkcs11-proxy.so
COPY --from=vegardit/softhsm2-pkcs11-proxy:latest-alpine /usr/local/lib/libpkcs11-proxy* /usr/local/lib/

# install test TLS Pre-Shared Key
COPY --from=vegardit/softhsm2-pkcs11-proxy:latest-alpine /opt/test.tls.psk /opt/test.tls.psk
