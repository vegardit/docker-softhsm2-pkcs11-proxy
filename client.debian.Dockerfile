# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-softhsm2-pkcs11-proxy

FROM debian:stable-slim

# install pkcs11-tool
RUN apt-get update && apt-get install -y opensc openssl

# install libpkcs11-proxy.so
COPY --from=vegardit/softhsm2-pkcs11-proxy:develop-debian /usr/local/lib/libpkcs11-proxy* /usr/local/lib/

# install test TLS Pre-Shared Key
COPY --from=vegardit/softhsm2-pkcs11-proxy:develop-debian /opt/test.tls.psk /opt/test.tls.psk
