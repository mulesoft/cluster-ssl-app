FROM artifacts.msap.io/mulesoft/core-paas-base-image-ubuntu:5.2.185

ARG CFSSL_VERSION=1.6.5
ARG KUBECTL_VER=1.30.3

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root
RUN apt-get update && \
    apt-get install --yes --no-install-recommends curl jq && \
    curl --fail -L https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssl_${CFSSL_VERSION}_linux_amd64 -o /usr/local/bin/cfssl && \
    curl --fail -L https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssljson_${CFSSL_VERSION}_linux_amd64 -o /usr/local/bin/cfssljson && \
    chmod a+x /usr/local/bin/cfssl* && \
    curl -L https://dl.k8s.io/release/v${KUBECTL_VER}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

USER 2020
COPY *.json /usr/src/app/
COPY hook.sh /usr/src/app/
WORKDIR /usr/src/app

ENTRYPOINT ["dumb-init", "/usr/src/app/hook.sh"]
