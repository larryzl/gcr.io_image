#!/bin/bash

#
# install kubernets
#

# k8s master 节点IP地址
m1="10.20.40.113"
m2="10.20.40.113"
m3="10.20.40.113"

# vip 地址
vip="10.20.40.88"

# 创建文件夹，设置环境变量
function init(){
    mkdir -p /etc/kubernetes/pki && cd /etc/kubernetes/pki
    export PKI_URL="https://kairen.github.io/files/manual-v1.10/pki"
    export KUBE_APISERVER="https://${vip}:6443"
}

# 生成CA
function ca(){
    wget "${PKI_URL}/ca-config.json" "${PKI_URL}/ca-csr.json"
    cfssl gencert -initca ca-csr.json | cfssljson -bare ca
}

# 生成apiserver 证书
function apiserver(){
    wget "${PKI_URL}/apiserver-csr.json"
    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca-config.json \
      -hostname=10.96.0.1,${vip},127.0.0.1,kubernetes.default \
      -profile=kubernetes \
      apiserver-csr.json | cfssljson -bare apiserver
}

# 生成front proxy 证书
function front-proxy(){
    # 生成front proxy金钥
    wget "${PKI_URL}/front-proxy-ca-csr.json"
    cfssl gencert \
        -initca front-proxy-ca-csr.json | cfssljson -bare front-proxy-ca

    # 生成front proxy client证书
    wget "${PKI_URL}/front-proxy-client-csr.json"
    cfssl gencert \
        -ca=front-proxy-ca.pem \
        -ca-key=front-proxy-ca-key.pem \
        -config=ca-config.json \
        -profile=kubernetes \
        front-proxy-client-csr.json | cfssljson -bare front-proxy-client
}

# 生成admin 证书
function admin(){
    wget "${PKI_URL}/admin-csr.json"

    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca-config.json \
      -profile=kubernetes \
      admin-csr.json | cfssljson -bare admin
}

# 生成admin.conf 配置文件
function admin_conf(){
    # admin set cluster
    kubectl config set-cluster kubernetes \
        --certificate-authority=ca.pem \
        --embed-certs=true \
        --server=${KUBE_APISERVER} \
        --kubeconfig=../admin.conf

    # admin set credentials
    kubectl config set-credentials kubernetes-admin \
        --client-certificate=admin.pem \
        --client-key=admin-key.pem \
        --embed-certs=true \
        --kubeconfig=../admin.conf

    # admin set context
    kubectl config set-context kubernetes-admin@kubernetes \
        --cluster=kubernetes \
        --user=kubernetes-admin \
        --kubeconfig=../admin.conf

    # admin set default context
    kubectl config use-context kubernetes-admin@kubernetes \
        --kubeconfig=../admin.conf
}

# 生成 kube controller manager 证书
function kube_controller_manager(){
    wget "${PKI_URL}/manager-csr.json"
    cfssl gencert \
        -ca=ca.pem \
        -ca-key=ca-key.pem \
        -config=ca-config.json \
        -profile=kubernetes \
    manager-csr.json | cfssljson -bare controller-manager
}

# 生成controller-manager.conf 配置文件
function controller_manager_cnof(){
    # controller-manager set cluster
    kubectl config set-cluster kubernetes \
        --certificate-authority=ca.pem \
        --embed-certs=true \
        --server=${KUBE_APISERVER} \
        --kubeconfig=../controller-manager.conf

    # controller-manager set credentials
    kubectl config set-credentials system:kube-controller-manager \
        --client-certificate=controller-manager.pem \
        --client-key=controller-manager-key.pem \
        --embed-certs=true \
        --kubeconfig=../controller-manager.conf

    # controller-manager set context
    kubectl config set-context system:kube-controller-manager@kubernetes \
        --cluster=kubernetes \
        --user=system:kube-controller-manager \
        --kubeconfig=../controller-manager.conf

    # controller-manager set default context
    kubectl config use-context system:kube-controller-manager@kubernetes \
        --kubeconfig=../controller-manager.conf
}

# 生成 kube-scheduler certificate 证书
function kube_scheduler(){
    wget "${PKI_URL}/scheduler-csr.json"

    cfssl gencert \
        -ca=ca.pem \
        -ca-key=ca-key.pem \
        -config=ca-config.json \
        -profile=kubernetes \
        scheduler-csr.json | cfssljson -bare scheduler

}

# 生成 scheduler.conf 配置文件
function scheduler_conf(){
    # scheduler set cluster
    kubectl config set-cluster kubernetes \
        --certificate-authority=ca.pem \
        --embed-certs=true \
        --server=${KUBE_APISERVER} \
        --kubeconfig=../scheduler.conf

    # scheduler set credentials
    kubectl config set-credentials system:kube-scheduler \
        --client-certificate=scheduler.pem \
        --client-key=scheduler-key.pem \
        --embed-certs=true \
        --kubeconfig=../scheduler.conf

    # scheduler set context
    kubectl config set-context system:kube-scheduler@kubernetes \
        --cluster=kubernetes \
        --user=system:kube-scheduler \
        --kubeconfig=../scheduler.conf

    # scheduler use default context
    kubectl config use-context system:kube-scheduler@kubernetes \
        --kubeconfig=../scheduler.conf
}

# 生成k8s kubelet 凭证
function kubelet(){
    wget "${PKI_URL}/kubelet-csr.json"
    # 生成kubelet凭证
    for NODE in k8s-m1 k8s-m2 k8s-m3; do
        echo "--- $NODE ---"
        cp kubelet-csr.json kubelet-$NODE-csr.json;
        sed -i "s/\$NODE/$NODE/g" kubelet-$NODE-csr.json;
        cfssl gencert \
          -ca=ca.pem \
          -ca-key=ca-key.pem \
          -config=ca-config.json \
          -hostname=$NODE \
          -profile=kubernetes \
          kubelet-$NODE-csr.json | cfssljson -bare kubelet-$NODE
    done

    for NODE in k8s-m2 k8s-m3; do
        echo "--- $NODE ---"
        ssh ${NODE} "mkdir -p /etc/kubernetes/pki"
        for FILE in kubelet-$NODE-key.pem kubelet-$NODE.pem ca.pem; do
            scp /etc/kubernetes/pki/${FILE} ${NODE}:/etc/kubernetes/pki/${FILE}
        done
    done

    for NODE in k8s-m1 k8s-m2 k8s-m3; do
        echo "--- $NODE ---"
        ssh ${NODE} "cd /etc/kubernetes/pki && \
        kubectl config set-cluster kubernetes \
            --certificate-authority=ca.pem \
            --embed-certs=true \
            --server=${KUBE_APISERVER} \
            --kubeconfig=../kubelet.conf && \
        kubectl config set-cluster kubernetes \
            --certificate-authority=ca.pem \
            --embed-certs=true \
            --server=${KUBE_APISERVER} \
            --kubeconfig=../kubelet.conf && \
        kubectl config set-credentials system:node:${NODE} \
            --client-certificate=kubelet-${NODE}.pem \
            --client-key=kubelet-${NODE}-key.pem \
            --embed-certs=true \
            --kubeconfig=../kubelet.conf && \
        kubectl config set-context system:node:${NODE}@kubernetes \
            --cluster=kubernetes \
            --user=system:node:${NODE} \
            --kubeconfig=../kubelet.conf && \
        kubectl config use-context system:node:${NODE}@kubernetes \
            --kubeconfig=../kubelet.conf && \
        rm kubelet-${NODE}.pem kubelet-${NODE}-key.pem"
    done
}

# Service account 不是通过 CA 进行认证，因此不要通过 CA 来做 Service account key 的检查，这边建立一组 Private 与 Public 金钥提供给 Service account key 使用：
function service_account(){
    openssl genrsa -out sa.key 2048
    openssl rsa -in sa.key -pubout -out sa.pub
    rm -rf *.json *.csr scheduler*.pem controller-manager*.pem admin*.pem kubelet*.pem
}

# 复制文件至其他节点
function sync_pki(){
    for NODE in k8s-m2 k8s-m3; do
        echo "--- $NODE ---"
        for FILE in $(ls /etc/kubernetes/pki/); do
            scp /etc/kubernetes/pki/${FILE} ${NODE}:/etc/kubernetes/pki/${FILE}
        done
    done

    for NODE in k8s-m2 k8s-m3; do
    echo "--- $NODE ---"
        for FILE in admin.conf controller-manager.conf scheduler.conf; do
            scp /etc/kubernetes/${FILE} ${NODE}:/etc/kubernetes/${FILE}
        done
    done
}