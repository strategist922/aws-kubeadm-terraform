#!/bin/bash -ve
touch /home/ubuntu/etcd.log

curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
touch /etc/apt/sources.list.d/kubernetes.list

su -c "echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' >> \
    /etc/apt/sources.list.d/kubernetes.list"

# Install kubelet kubeadm kubectl kubernetes-cni docker
apt-get update
apt-get install -y kubelet kubeadm kubectl kubernetes-cni
curl -sSL https://get.docker.com/ | sh
systemctl start docker
echo '[Finished] Installing kubelet kubeadm kubectl kubernetes-cni docker' > /home/ubuntu/etcd.log

# Install etcdctl for the version of etcd we're running
ETCD_VERSION=$(kubeadm config images list | grep etcd | cut -d':' -f2)
wget "https://github.com/coreos/etcd/releases/download/v$${ETCD_VERSION}/etcd-v$${ETCD_VERSION}-linux-amd64.tar.gz"
tar xvf "etcd-v$${ETCD_VERSION}-linux-amd64.tar.gz"
mv "etcd-v$${ETCD_VERSION}-linux-amd64/etcdctl" /usr/local/bin/
rm -rf etcd*
echo '[Finished] Installing etcdctl' > /home/ubuntu/etcd.log

systemctl stop docker
mkdir /mnt/docker
chmod 711 /mnt/docker
cat <<EOF > /etc/docker/daemon.json
{
    "data-root": "/mnt/docker",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "5"
    }
}
EOF
systemctl start docker
systemctl enable docker
echo '[Finished] docker configure' > /home/ubuntu/etcd.log

# Point kubelet at big ephemeral drive
mkdir /mnt/kubelet
echo 'KUBELET_EXTRA_ARGS="--root-dir=/mnt/kubelet --cloud-provider=aws"' > /etc/default/kubelet
echo '[Finished] kubelet configure' > /home/ubuntu/etcd.log

# ----------------- from here same with etcd.sh

# Pass bridged IPv4 traffic to iptables chains (required by Flannel)
echo "net.bridge.bridge-nf-call-iptables = 1" > /etc/sysctl.d/60-flannel.conf
service procps start

echo '[Wait] kubeadm join until kubeadm cluster have been created.' > /home/ubuntu/etcd.log
for i in {1..50}; do sudo kubeadm join --token=${k8stoken} --discovery-token-unsafe-skip-ca-verification --node-name=$(hostname -f) ${masterIP}:6443 && break || sleep 15; done
