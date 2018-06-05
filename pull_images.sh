#!/bin/sh


docker pull larryzl/etcd-amd64:3.1.13
docker pull kairen/haproxy:1.7
docker pull kairen/keepalived:1.2.24
docker pull larryzl/kube-apiserver-amd64:v1.10.0
docker pull larryzl/kube-controller-manager-amd64:v1.10.0
docker pull larryzl/kube-scheduler-amd64:v1.10.0
docker pull larryzl/pause-amd64:3.1

docker tag larryzl/etcd-amd64:3.1.13 gcr.io/google_containers/etcd-amd64:3.1.13
docker tag larryzl/kube-apiserver-amd64:v1.10.0 gcr.io/google_containers/kube-apiserver-amd64:v1.10.0
docker tag larryzl/kube-scheduler-amd64:v1.10.0 gcr.io/google_containers/kube-scheduler-amd64:v1.10.0
docker tag larryzl/pause-amd64:3.1 k8s.gcr.io/pause-amd64:3.1
docker tag larryzl/kube-controller-manager-amd64:v1.10.0 gcr.io/google_containers/kube-controller-manager-amd64:v1.10.0