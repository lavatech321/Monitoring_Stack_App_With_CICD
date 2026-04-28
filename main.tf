
resource "aws_key_pair" "mykey" {
    key_name = "terraform-ansible-key-2"
    #public_key = file("C:/Users/username/.ssh/id_rsa.pub")
    public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_security_group" "jenkins-allow" {
    name = "allow-jenkins"
    description = "Allow only jenkins port"
    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "ssh-allow" {
    name = "allow-ssh-ansible-2"
    description = "Allow only ssh port"
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "reactjs-allow" {
    name = "allow-reactjs"
    description = "Allow only reactjs port"
    ingress {
        from_port = 3000
        to_port = 3000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "spring-allow" {
    name = "allow-spring"
    description = "Allow only spring port"
    ingress {
        from_port = 7093
        to_port = 7093
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "monitoring-allow" {
  name        = "allow-monitoring"
  description = "Allow Jaeger and Prometheus ports"

  # Jaeger UI
  ingress {
    description = "Jaeger UI"
    from_port   = 16686
    to_port     = 16686
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Prometheus UI
  ingress {
    description = "Prometheus UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu_22" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "servers" {
    ami = data.aws_ami.ubuntu_22.id
    instance_type = "m7i-flex.large"
    key_name = aws_key_pair.mykey.key_name
    root_block_device {
	  volume_size           = 40
	  volume_type           = "gp3"
	  delete_on_termination = true
	  encrypted             = true
    }
    vpc_security_group_ids = [
    aws_security_group.ssh-allow.id,
    aws_security_group.reactjs-allow.id,
    aws_security_group.spring-allow.id,
    aws_security_group.monitoring-allow.id,
    aws_security_group.jenkins-allow.id
]

    connection {
                type     = "ssh"
                user     = "ubuntu"
                private_key = file("~/.ssh/id_rsa")
                host = aws_instance.servers.public_ip
        }
	provisioner "file" {
    		source      = "configure-jenkins.sh"
		destination = "/home/ubuntu/code.sh"
  	}
	provisioner "file" {
    		source      = "execute-groovy.groovy"
		destination = "/home/ubuntu/pipeline.groovy"
  	}

	provisioner "remote-exec" {
  inline = [
    "sudo apt update -y",
    "sudo apt install -y ca-certificates curl gnupg git openjdk-21-jdk wget",

    # Jenkins install
    "wget https://pkg.jenkins.io/debian-stable/binary/jenkins_2.555.1_all.deb -O /tmp/jenkins.deb",
    "sudo apt install -y /tmp/jenkins.deb",
    "sudo systemctl enable jenkins",
    "sudo systemctl start jenkins",

    "chmod +x /home/ubuntu/code.sh",
    "sudo bash /home/ubuntu/code.sh",

    # Docker install
    "sudo apt-get update",
    "sudo apt-get install -y ca-certificates curl gnupg lsb-release",
    "sudo mkdir -p /etc/apt/keyrings",

    "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg",
    "sudo chmod a+r /etc/apt/keyrings/docker.gpg",

    "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",

    "sudo apt-get update",
    "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",

    "sudo systemctl enable docker",
    "sudo systemctl start docker",

    # Add users safely
    "sudo usermod -aG docker ubuntu || true",
    "sudo usermod -aG docker jenkins || true",

    # Jenkins pipeline setup
    "sudo mkdir -p /var/lib/jenkins/init.groovy.d",
    "sudo cp /home/ubuntu/pipeline.groovy /var/lib/jenkins/init.groovy.d/pipeline.groovy",
    "sudo chown jenkins:jenkins /var/lib/jenkins/init.groovy.d/pipeline.groovy",

    # set ec2-instance ip in jenkins job
    "sudo sed -i 's/PUBLIC-IP/${self.public_ip}/g' /var/lib/jenkins/init.groovy.d/pipeline.groovy",

    "sudo systemctl restart docker",
    "sudo systemctl restart jenkins"
  ]
}	

}

output "EC2-Instance-access-details" {
	value = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.servers.public_ip} \n"
}

output "Jenkins-UI" {
	value = "http://${aws_instance.servers.public_ip}:8080 \n"
}

output "SpringBoot-Application-Backend" {
	value = "http://${aws_instance.servers.public_ip}:7093 \n"
}

output "React-Application-Frontend" {
	value = "http://${aws_instance.servers.public_ip}:3000 \n"
}

output "Jaeger-Distributed-Tracing" {
	value = "http://${aws_instance.servers.public_ip}:16686 \n"
}

output "Prometheus-Monitoring" {
	value = "http://${aws_instance.servers.public_ip}:9090 \n"
}
