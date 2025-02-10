#!/bin/bash

# Containerd installation script
echo "Starting containerd setup..."

# Create containerd configuration file with necessary modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Load containerd modules
sudo modprobe overlay
sudo modprobe br_netfilter

# Configure sysctl parameters
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl parameters
sudo sysctl --system

# Verify that the necessary kernel modules are loaded
lsmod | grep br_netfilter
lsmod | grep overlay

# Verify sysctl settings
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

# Update package list
sudo apt-get update

# Install containerd
sudo apt-get -y install containerd

# Create a default config file for containerd if not present
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Update `SystemdCgroup` setting in containerd config
sudo sed -i '/SystemdCgroup =/c\            SystemdCgroup = true' /etc/containerd/config.toml

# Restart containerd to apply changes
sudo systemctl restart containerd

# Install dependencies for Kubernetes
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Add Kubernetes signing key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list

# Update package list again
sudo apt-get update

# Install Kubernetes components
sudo apt-get install -y kubelet kubeadm kubectl

# Prevent automatic upgrades of Kubernetes components
sudo apt-mark hold kubelet kubeadm kubectl

echo "Containerd and Kubernetes setup completed successfully!"
