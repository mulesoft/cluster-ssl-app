FROM golang:1.24.13 AS cfssl-builder
ARG CFSSL_VERSION=1.6.5
RUN git clone --branch v${CFSSL_VERSION} --depth 1 https://github.com/cloudflare/cfssl.git /src/cfssl && \
    cd /src/cfssl && \
    CGO_ENABLED=0 go build -o /usr/local/bin/cfssl ./cmd/cfssl && \
    CGO_ENABLED=0 go build -o /usr/local/bin/cfssljson ./cmd/cfssljson

FROM artifacts.msap.io/mulesoft/supply-chain-rhel9-base-image:5.0.14

ARG KUBECTL_VER=1.32.13

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root
RUN apt-get update && \
    apt-get install --yes --no-install-recommends curl jq && \
    curl -L https://dl.k8s.io/release/v${KUBECTL_VER}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

COPY --from=cfssl-builder /usr/local/bin/cfssl /usr/local/bin/cfssl
COPY --from=cfssl-builder /usr/local/bin/cfssljson /usr/local/bin/cfssljson

USER 2020
COPY *.json /usr/src/app/
COPY hook.sh /usr/src/app/
WORKDIR /usr/src/app

ENTRYPOINT ["dumb-init", "/usr/src/app/hook.sh"]
