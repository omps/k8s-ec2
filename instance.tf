# Creating key-pair on AWS using SSH-public key
resource "aws_key_pair" "deployer" {
  key_name   = var.key-name
  public_key = file("${path.module}/k8s-key.pub")
}

# Creating a security group to restrict/allow inbound and outbound connectivity
resource "aws_security_group" "network-security-group" {
  name        = var.network-security-group-name
  description = "Allow necessary inbound and outbound traffic"

  # Ingress Rules (Inbound)
  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Secure Kubernetes API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 # ✅ Control Plane (Kubernetes API Server - External Access Allowed)
  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 🚨 Restrict this to trusted IPs for security!
  }
 # ✅ Control Plane (Internal etcd communication)
  ingress {
    description = "etcd server client API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]  # Allow only internal traffic
  }

  # ✅ Control Plane (Internal etcd communication)
  ingress {
    description = "etcd server client API"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]  # Allow only internal traffic
  }

  # ✅ Control Plane (Internal kubelet API)
  ingress {
    description = "Kubelet API (Control Plane)"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]  # Allow only internal traffic
  }

  # ✅ Control Plane (Internal kube-scheduler)
  ingress {
    description = "Kube-scheduler"
    from_port   = 10259
    to_port     = 10259
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]  # Allow only internal traffic
  }

  # ✅ Control Plane (Internal kube-controller-manager)
  ingress {
    description = "Kube-controller-manager"
    from_port   = 10257
    to_port     = 10257
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]  # Allow only internal traffic
  }

  # ✅ Worker Nodes (Internal kube-proxy)
  ingress {
    description = "kube-proxy"
    from_port   = 10256
    to_port     = 10256
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]  # Allow only internal traffic
  }

  # ✅ Worker Nodes (NodePort Services)
  ingress {
    description = "NodePort Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]  # Allow only internal traffic
  }
  
  ingress {
    description = "Ping among private nets"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.private_subnet_cidr]  # Allow only internal traffic
  }

  ingress {
    description = "Waevenet CNI UDP"
    from_port   = 6783
    to_port     = 6784
    protocol    = "udp"
    cidr_blocks = [var.private_subnet_cidr]  # Allow only internal traffic
  }

  ingress {
    description = "Waevenet CNI"
    from_port   = 6783
    to_port     = 6783
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_cidr]  # Allow only internal traffic
  }

  # Egress Rules (Outbound)
  egress {
    description = "Allow all outbound IPv4 traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow all outbound IPv6 traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "k8s-cluster"
  }
}

# Creating Ubuntu EC2 instances
resource "aws_instance" "k8s-ctrlr" {
  ami                         = var.ubuntu-ami
  instance_type               = var.ubuntu-instance-ctrlr
  key_name                    = aws_key_pair.deployer.key_name
  vpc_security_group_ids      = [aws_security_group.network-security-group.id]
  associate_public_ip_address = true
  tags = {
    Name = "k8s-controller"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${path.module}/k8s-key")
    host        = self.public_ip
  }

  provisioner "file" {
    source      = "${path.module}/k8setup.sh"
    destination = "/tmp/k8setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/k8setup.sh",
      "sudo /tmp/k8setup.sh"
    ]
  }
}

resource "aws_instance" "k8s-n1" {
  ami                         = var.ubuntu-ami
  instance_type               = var.ubuntu-instance-node
  key_name                    = aws_key_pair.deployer.key_name
  vpc_security_group_ids      = [aws_security_group.network-security-group.id]
  associate_public_ip_address = true
  tags = {
    Name = "k8s-node1"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${path.module}/k8s-key")
    host        = self.public_ip
  }

  provisioner "file" {
    source      = "${path.module}/k8setup.sh"
    destination = "/tmp/k8setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/k8setup.sh",
      "sudo /tmp/k8setup.sh"
    ]
  }
}

resource "aws_instance" "k8s-n2" {
  ami                         = var.ubuntu-ami
  instance_type               = var.ubuntu-instance-node
  key_name                    = aws_key_pair.deployer.key_name
  vpc_security_group_ids      = [aws_security_group.network-security-group.id]
  associate_public_ip_address = true
  tags = {
    Name = "k8s-node2"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${path.module}/k8s-key")
    host        = self.public_ip
  }

  provisioner "file" {
    source      = "${path.module}/k8setup.sh"
    destination = "/tmp/k8setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/k8setup.sh",
      "sudo /tmp/k8setup.sh"
    ]
  }
}

# Function to generate /etc/hosts entries for instances
locals {
  etc_hosts = <<EOT
# Kubernetes Cluster Hosts - Managed by Terraform
${aws_instance.k8s-ctrlr.private_ip} k8s-controller
${aws_instance.k8s-n1.private_ip} k8s-node1
${aws_instance.k8s-n2.private_ip} k8s-node2
EOT
}

# Updating /etc/hosts on ALL EC2 instances
resource "null_resource" "update_hosts" {
  depends_on = [
    aws_instance.k8s-ctrlr,
    aws_instance.k8s-n1,
    aws_instance.k8s-n2
  ]

  # Update /etc/hosts on k8s-controller
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${path.module}/k8s-key")
      host        = aws_instance.k8s-ctrlr.public_ip
    }

    inline = [
      "echo '127.0.0.1 localhost' | sudo tee /etc/hosts",
      "echo '${aws_instance.k8s-ctrlr.private_ip} k8s-controller' | sudo tee -a /etc/hosts",
      "echo '${aws_instance.k8s-n1.private_ip} k8s-node1' | sudo tee -a /etc/hosts",
      "echo '${aws_instance.k8s-n2.private_ip} k8s-node2' | sudo tee -a /etc/hosts"
    ]
  }

  # Update /etc/hosts on k8s-node1
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${path.module}/k8s-key")
      host        = aws_instance.k8s-n1.public_ip
    }

    inline = [
      "echo '127.0.0.1 localhost' | sudo tee /etc/hosts",
      "echo '${aws_instance.k8s-ctrlr.private_ip} k8s-controller' | sudo tee -a /etc/hosts",
      "echo '${aws_instance.k8s-n1.private_ip} k8s-node1' | sudo tee -a /etc/hosts",
      "echo '${aws_instance.k8s-n2.private_ip} k8s-node2' | sudo tee -a /etc/hosts"
    ]
  }

  # Update /etc/hosts on k8s-node2
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${path.module}/k8s-key")
      host        = aws_instance.k8s-n2.public_ip
    }

    inline = [
      "echo '127.0.0.1 localhost' | sudo tee /etc/hosts",
      "echo '${aws_instance.k8s-ctrlr.private_ip} k8s-controller' | sudo tee -a /etc/hosts",
      "echo '${aws_instance.k8s-n1.private_ip} k8s-node1' | sudo tee -a /etc/hosts",
      "echo '${aws_instance.k8s-n2.private_ip} k8s-node2' | sudo tee -a /etc/hosts"
    ]
  }
}


# Updating /etc/hosts on the local Mac
resource "null_resource" "update_local_hosts" {
  depends_on = [
    aws_instance.k8s-ctrlr,
    aws_instance.k8s-n1,
    aws_instance.k8s-n2
  ]

  provisioner "local-exec" {
    command = <<EOT
      sudo sed -i '' '/# Kubernetes Cluster Hosts - Managed by Terraform/,$d' /etc/hosts
      echo "# Kubernetes Cluster Hosts - Managed by Terraform" | sudo tee -a /etc/hosts
      echo "${aws_instance.k8s-ctrlr.public_ip} k8s-controller" | sudo tee -a /etc/hosts
      echo "${aws_instance.k8s-n1.public_ip} k8s-node1" | sudo tee -a /etc/hosts
      echo "${aws_instance.k8s-n2.public_ip} k8s-node2" | sudo tee -a /etc/hosts
    EOT
  }
}

