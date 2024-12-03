FROM artifacts.msap.io/mulesoft/core-paas-base-image-ubuntu:5.2.199

USER root
RUN apt-get update && \
    apt-get install --yes --no-install-recommends curl jq && \
    curl --fail -L https://github.com/cloudflare/cfssl/releases/download/1.2.0/cfssl_linux-amd64 -o /usr/local/bin/cfssl && \
    curl --fail -L https://github.com/cloudflare/cfssl/releases/download/1.2.0/cfssljson_linux-amd64 -o /usr/local/bin/cfssljson && \
    mkdir -p /root/cfssl

ADD *.json /root/cfssl/

RUN chmod a+x /usr/local/bin/cfssl*

ADD hook.sh /hook.sh
USER app

ENTRYPOINT ["dumb-init", "/hook.sh"]
