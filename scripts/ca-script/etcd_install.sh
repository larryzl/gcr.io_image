#!/bin/bash

#
# install etcd
#

# k8s master 节点IP地址
m1="10.20.40.113"
m2="10.20.40.113"
m3="10.20.40.113"

# vip 地址
vip="10.20.40.88"


mkdir -p /etc/etcd/ssl && cd /etc/etcd/ssl

export PKI_URL="https://kairen.github.io/files/manual-v1.10/pki"

wget "${PKI_URL}/ca-config.json" "${PKI_URL}/etcd-ca-csr.json"

cfssl gencert -initca etcd-ca-csr.json | cfssljson -bare etcd-ca

wget "${PKI_URL}/etcd-csr.json"

cfssl gencert \
  -ca=etcd-ca.pem \
  -ca-key=etcd-ca-key.pem \
  -config=ca-config.json \
  -hostname=127.0.0.1,${m1},${m2},${m3} \
  -profile=kubernetes \
  etcd-csr.json | cfssljson -bare etcd

rm -rf *.json *.csr

for NODE in k8s-m2 k8s-m3; do
    echo "--- $NODE ---"
    ssh ${NODE} "mkdir -p /etc/etcd/ssl"
    for FILE in etcd-ca-key.pem  etcd-ca.pem  etcd-key.pem  etcd.pem; do
        scp /etc/etcd/ssl/${FILE} ${NODE}:/etc/etcd/ssl/${FILE}
    done
done

