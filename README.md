<div align="center">

# 🏦 DevSecOps Banking Application (Master Guide)

A high-performance, containerized banking application built with **Spring Boot 3**, **Java 21**, and **Integrated AI (Ollama)**. This repository provides a complete "Golden Pipeline" setup following modern DevSecOps best practices.

[![Java Version](https://img.shields.io/badge/Java-21-blue.svg)](https://www.oracle.com/java/technologies/javase/jdk21-archive-downloads.html)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.4.1-brightgreen.svg)](https://spring.io/projects/spring-boot)
[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-orange.svg)](.github/workflows/devsecops.yml)
[![AWS OIDC](https://img.shields.io/badge/Security-OIDC-red.svg)](#phase-2-security--identity-iam-oidc)

</div>

---

## 🏗️ Architecture Overview

The system follows a multi-tier, secure architecture deployed on AWS:

```mermaid
graph TD
    subgraph "External"
        GH[GitHub Actions]
        User[User Browser]
    end

    subgraph "AWS Cloud (VPC)"
        subgraph "Application Tier"
            AppEC2[App EC2 - Docker]
        end

        subgraph "Database Tier"
            RDS[(Amazon RDS - MySQL)]
        end

        subgraph "AI Tier"
            Ollama[Ollama EC2 - AI Engine]
        end

        subgraph "Security & Identity"
            Secrets[AWS Secrets Manager]
            OIDC[IAM OIDC Provider]
        end

        subgraph "Container Registry"
            ECR[Amazon ECR]
        end
    end

    GH -->|1. OIDC Auth| OIDC
    GH -->|2. Push Image| ECR
    GH -->|3. SSH Deploy| AppEC2
    
    User -->|Port 8080| AppEC2
    AppEC2 -->|Database Connection| RDS
    AppEC2 -->|REST API| Ollama
    AppEC2 -->|Fetch Credentials| Secrets
    AppEC2 -->|Pull Image| ECR
```

---

## 🚀 Setup & Deployment Guide

Follow these five phases to implement the project exactly as documented.

### Phase 1: AWS Infrastructure Foundation

#### 1. Amazon ECR (Container Registry)
- Create a private repository named `devsecops-bankapp`.
- **Note**: Copy the **Repository URI** for later use in GitHub Secrets.

#### 2. Application EC2 (Web Tier)
- Launch an Ubuntu 22.04 instance.
- **Security Group**: Open **Port 22** (SSH) and **Port 8080** (App).
- **IAM Profile (CRITICAL)**: Attach a role to this EC2 with the following managed policies:
  - `AmazonEC2ContainerRegistryPowerUser`
  - `AWSSecretsManagerClientReadOnlyAccess`
- **Install Prerequisites**:

  ```bash
  sudo apt update && sudo apt install -y docker.io docker-compose-v2 jq mysql-client
  sudo usermod -aG docker $USER && newgrp docker
  sudo snap install aws-cli --classic
  ```

#### 3. Amazon RDS (MySQL Database)
- Launch a MySQL 8.0 instance using the **Dev/Test** template.
- **Connectivity**: Use the **"Set up EC2 connection"** feature during creation to automatically attach your **App EC2**. This handles the Security Group rules for Port 3306 automatically.
- **Note**: Copy the **RDS Endpoint**.

#### 4. Ollama EC2 (AI Tier)
- Launch a separate Ubuntu EC2 (t3.medium recommended).
- **Security Group**: Open **Port 11434** to the **App EC2's Security Group**.

Automate your Ollama server setup by running this script as [USER DATA While launching EC2](scripts/ollama-setup.sh):

*This script installs Ollama, enables external access (0.0.0.0), and pulls the `tinyllama` model.*



---

### Phase 2: Database Initialization

Once your RDS is live and you have installed the `mysql-client` on your App EC2:

1.  **Connect to RDS**:

    ```bash
    mysql -h <YOUR-RDS-ENDPOINT> -u <YOUR-USERNAME> -p
    ```
2.  **Create the Database**:

    ```sql
    CREATE DATABASE bankappdb;
    EXIT;
    ```

---

### Phase 4: Security & Identity (IAM OIDC)

We use **GitHub OIDC** for passwordless AWS authentication.

1.  **Identity Provider**: In IAM, Identity providers -> Add Provider -> OpenID Connect.
    - URL: `https://token.actions.githubusercontent.com`
    - Audience: `sts.amazonaws.com`
2.  **IAM Role**: Create a role named `GitHubActionsRole` for **Web Identity**.
3.  **Trust Policy**: Use this JSON (Replace `<ACCOUNT-ID>`, `<ORG>`, and `<REPO>`):
    ```json
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": { "Federated": "arn:aws:iam::<ACCOUNT-ID>:oidc-provider/token.actions.githubusercontent.com" },
          "Action": "sts:AssumeRoleWithWebIdentity",
          "Condition": { "StringLike": { "token.actions.githubusercontent.com:sub": "repo:<ORG>/<REPO>:*" } }
        }
      ]
    }
    ```
4.  **Permissions**: Attach `AmazonEC2ContainerRegistryPowerUser` to this role.

---

### Phase 5: Secrets & GitHub Configuration

#### 1. AWS Secrets Manager
Create a secret named `bankapp/prod-secrets` with these EXACT keys:
- `DB_HOST`: <RDS-Endpoint>
- `DB_PORT`: `3306`
- `DB_NAME`: `bankappdb`
- `DB_USER`: <Your-RDS-Username>
- `DB_PASSWORD`: <Your-RDS-Password>
- `OLLAMA_URL`: `http://<OLLAMA-PRIVATE-IP>:11434`

#### 2. GitHub Action Secrets
Add these to your repository settings (Settings -> Secrets -> Actions):
- `AWS_ROLE_ARN`: <ARN-of-GitHubActionsRole>
- `AWS_REGION`: <Your-Region>
- `AWS_ACCOUNT_ID`: <Your-12-digit-ID>
- `ECR_REPOSITORY`: `devsecops-bankapp`
- `EC2_HOST`: <App-EC2-Public-IP>
- `EC2_USER`: `ubuntu`
- `EC2_SSH_KEY`: <Your-Private-Key-Content>

---

## 🛠️ CI/CD Pipeline Workflow

The pipeline runs automatically on every `git push`:

1.  **Build**: Compiles Java 21 code with Maven.
2.  **Containerize**: Builds and pushes the Docker image to ECR using OIDC.
3.  **Transfer**: Copies [`app-tier.yml`](app-tier.yml) to the App EC2.
4.  **Deploy**: 
    - Fetches credentials from Secrets Manager.
    - Creates a dynamic `.env` file.
    - Runs `docker compose up -d --build`.

---

## 🧪 Verification Commands

- **Check App Status**: `docker ps`
- **Verify DB Rows**: 

  ```bash
  mysql -h <RDS-ENDPOINT> -u admin -p bankappdb -e "SELECT * FROM accounts;"
  ```
- **Check AI Connectivity**:

  ```bash
  nc -zv <OLLAMA-PRIVATE-IP> 11434
  ```

---

<div align="center">

⭐ **TrainWithShubham** ⭐
*Empowering engineers with real-world DevSecOps projects.*
</div>
