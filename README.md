# Monitoring Stack Application Deployment (AWS EC2 + Docker Compose)

This project provisions an **Amazon Linux EC2 instance using Terraform** and automatically deploys a **full monitoring-enabled application stack** using Docker Compose.

It includes:

* ReactJS Frontend
* Spring Boot Backend
* Observability stack (Jaeger + Prometheus)

---

# Technologies Used

| Layer             | Technology                                |
| ----------------- | ----------------------------------------- |
| Infrastructure    | Terraform, AWS EC2 (Amazon Linux)         |
| Container Runtime | Docker                                    |
| Orchestration     | Docker Compose                            |
| Frontend          | ReactJS                                   |
| Backend           | Spring Boot (Java 17)                     |
| Observability     | Jaeger (Tracing), Prometheus (Monitoring) |
| Version Control   | GitHub                                    |

---

# Architecture Diagram

```
                     ┌────────────────────────────┐
                     │        User Browser        │
                     │ http://<EC2-IP>:3000      │
                     └────────────┬───────────────┘
                                  │
                                  ▼
                  ┌────────────────────────────────┐
                  │       AWS EC2 Instance         │
                  │       (Amazon Linux)           │
                  └────────────┬───────────────────┘
                               │
                         Docker Engine
                               │
                    ┌──────────┴──────────┐
                    │   Docker Compose    │
                    └──────────┬──────────┘
                               │
        ┌──────────────┬──────────────┬──────────────┬──────────────┐
        ▼              ▼              ▼              ▼
┌────────────┐  ┌──────────────┐  ┌────────────┐  ┌──────────────┐
│ React App  │  │ Spring Boot  │  │ Jaeger UI  │  │ Prometheus   │
│ Port:3000  │  │ Port:7093    │  │ Port:16686 │  │ Port:9090    │
└────────────┘  └──────────────┘  └────────────┘  └──────────────┘
```

---

# What This Setup Does

Terraform automatically:

* Launches EC2 instance
* Installs Git & Docker
* Configures Docker Compose
* Clones application repository
* Updates frontend API URL dynamically
* Starts full stack using Docker Compose

---

# How to Run

## Step 1: Initialize Terraform

```bash
git clone https://github.com/lavatech321/Monitoring_Stack_App.git
cd Monitoring_Stack_App
terraform init
```

---

## Step 2: Apply Configuration

```bash
terraform apply --auto-approve
```

---

# Terraform Outputs

```hcl
output "EC2-Instance-access-details" {
	value = "ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.servers.public_ip} \n"
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
```

---

# Application Access URLs

| Service               | URL                   |
| --------------------- | --------------------- |
| Frontend (ReactJS)    | http://<EC2-IP>:3000  |
| Backend (Spring Boot) | http://<EC2-IP>:7093  |
| Jaeger UI             | http://<EC2-IP>:16686 |
| Prometheus            | http://<EC2-IP>:9090  |

---

# SSH Access

```bash
ssh -i ~/.ssh/id_rsa ec2-user@<EC2_PUBLIC_IP>
```

---

# Key Features

* Fully automated infrastructure + application deployment
* Dynamic IP substitution in frontend
* Integrated observability (Tracing + Metrics)
* Single-command deployment using Terraform
* No manual Docker setup required

---

# Conclusion

This project demonstrates a **complete DevOps workflow**:

```
Terraform → EC2 → Docker → Docker Compose → Full Stack + Monitoring
```

---

