#!/bin/bash

#
#
#

# k8s master 节点IP地址
m1="10.20.40.113"
m2="10.20.40.113"
m3="10.20.40.113"

# vip 地址
vip="10.20.40.88"

export CORE_URL="https://kairen.github.io/files/manual-v1.10/master"
mkdir -p /etc/kubernetes/manifests && cd /etc/kubernetes/manifests

for FILE in kube-apiserver kube-controller-manager kube-scheduler haproxy keepalived etcd etcd.config; do
    wget "${CORE_URL}/${FILE}.yml.conf" -O ${FILE}.yml
    if [ ${FILE} == "etcd.config" ]; then
        mv etcd.config.yml /etc/etcd/etcd.config.yml
        sed -i "s/\${HOSTNAME}/${HOSTNAME}/g" /etc/etcd/etcd.config.yml
        sed -i "s/\${PUBLIC_IP}/$(hostname -i)/g" /etc/etcd/etcd.config.yml
    fi
done


cat <<EOF > /etc/kubernetes/encryption.yml
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
        keys:
          - name: key1
            ecret: IGB8IZtV+dUeuK72ROUkedUgZVPkeAqdRaXLI6US4kI=
      - identity: {}
EOF

cat <<EOF > /etc/kubernetes/audit-policy.yml
apiVersion: audit.k8s.io/v1beta1
kind: Policy
rules:- level: Metadata
EOF

mkdir -p /etc/haproxy/
wget "${CORE_URL}/haproxy.cfg" -O /etc/haproxy/haproxy.cfg

mkdir -p /etc/systemd/system/kubelet.service.d

wget "${CORE_URL}/kubelet.service" -O /lib/systemd/system/kubelet.service

wget "${CORE_URL}/10-kubelet.conf" -O /etc/systemd/system/kubelet.service.d/10-kubelet.conf

mkdir -p /var/lib/kubelet /var/log/kubernetes /var/lib/etcd

systemctl enable kubelet.service && systemctl start kubelet.service

watch netstat -ntlp

cp /etc/kubernetes/admin.conf ~/.kube/config
kubectl get cs
