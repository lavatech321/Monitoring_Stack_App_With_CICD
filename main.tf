
resource "aws_key_pair" "mykey" {
    key_name = "terraform-ansible-key1"
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
    name = "allow-ssh-ansible"
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


data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "servers" {
    ami = data.aws_ami.amazon_linux.id
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
                user     = "ec2-user"
                private_key = file("~/.ssh/id_rsa")
                host = aws_instance.servers.public_ip
        }
	provisioner "file" {
    		source      = "configure-jenkins.sh"
		destination = "/home/ec2-user/code.sh"
  	}
	provisioner "file" {
    		source      = "execute-groovy.groovy"
		destination = "/home/ec2-user/pipeline.groovy"
  	}
	provisioner "remote-exec" {
  inline = [
	"sudo yum update -y",
	"sudo yum install git -y",
	"sudo yum install java-17-amazon-corretto -y",

    # Install Jenkins
    "sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo",
    "sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key",
    "sudo yum install jenkins -y",
    #"sudo systemctl enable jenkins",

    # Configure jenkins
    "sudo chmod +x /home/ec2-user/code.sh",
    "bash /home/ec2-user/code.sh",
    "bash /home/ec2-user/code.sh",

    # docker install
			"sudo yum install docker-io -y",
  			"sudo hostnamectl set-hostname demo.example.com",
			"sudo systemctl start docker",
			"sudo systemctl enable docker",
			"sudo usermod -aG docker $USER",
			"sudo usermod -aG docker jenkins",
			"sudo mkdir -p /usr/local/lib/docker/cli-plugins",
			"sudo curl -SL https://github.com/docker/compose/releases/download/v2.25.0/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose",
			"sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose",
			"sudo cp /home/ec2-user/pipeline.groovy /var/lib/jenkins/init.groovy.d/pipeline.groovy",
			"sudo chown jenkins:jenkins  /var/lib/jenkins/init.groovy.d/pipeline.groovy",
			"sudo systemctl restart docker",
			"sudo systemctl restart jenkins",
  ]
}
}

output "EC2-Instance-access-details" {
	value = "ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.servers.public_ip} \n"
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
