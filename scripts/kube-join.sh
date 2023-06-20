#!/bin/bash

exec   > >(tee -ia /var/log/kube-join.log)
exec  2> >(tee -ia /var/log/kube-join.log >& 2)
exec 19>> /var/log/kube-join.log

export BASH_XTRACEFD="19"
set -ex

NODE_ROLE=$1
KUBE_VIP_LOC="/etc/kubernetes/manifests/kube-vip.yaml"
do_kubeadm_reset() {
  kubeadm reset -f
  iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X && rm -rf /etc/kubernetes/etcd /etc/kubernetes/manifests /etc/kubernetes/pki
}

backup_kube_vip_manifest_if_present() {
  if [ -f "$KUBE_VIP_LOC" ] && [ "$NODE_ROLE" != "worker" ]; then
    cp $KUBE_VIP_LOC /opt/kubeadm/kube-vip.yaml
  fi
}

restore_kube_vip_manifest_after_reset() {
  if [ -f "/opt/kubeadm/kube-vip.yaml" ] && [ "$NODE_ROLE" != "worker" ]; then
      mkdir -p /etc/kubernetes/manifests
      cp /opt/kubeadm/kube-vip.yaml $KUBE_VIP_LOC
  fi
}

until kubeadm join --config /opt/kubeadm/kubeadm.yaml --ignore-preflight-errors=DirAvailable--etc-kubernetes-manifests -v=5 > /dev/null
do
  backup_kube_vip_manifest_if_present
  echo "failed to apply kubeadm join, will retry in 10s";
  kubeadm reset -f
  iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X && rm -rf /etc/kubernetes/etcd /etc/kubernetes/manifests /etc/kubernetes/pki
  echo "retrying in 10s"
  sleep 10;
  restore_kube_vip_manifest_after_reset
done;