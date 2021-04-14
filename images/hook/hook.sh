#!/bin/bash

set -xe

function upsert_certificate_secrets {
	cfssl gencert -initca ca-csr.json|cfssljson -bare ca -
	cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
			  -profile=server default-server-csr.json | cfssljson -bare default-server
	cp default-server.pem default-server-with-chain.pem
	cat ca.pem >> default-server-with-chain.pem

	helm3 upgrade --install cluster-ssl /var/lib/gravity/resources/charts/cluster-ssl
}

cd /root/cfssl

if [[ $1 == "install" || $1 == "update" ]]; then
    upsert_certificate_secrets

elif [[ $1 == "uninstall" ]]; then
	helm3 uninstall cluster-ssl

else
	echo "Missing argument, should be 'install', 'update' or 'uninstall'"
	exit 1

fi
