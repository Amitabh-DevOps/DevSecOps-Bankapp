# DevSecOps Banking Application

<div align="center">


A robust, containerized banking application built on Spring Boot 3 and Java 21. This project demonstrates modern financial software architecture, integrating Java's virtual threads for high concurrency, a contextual AI assistant for user engagement, and integrated DevSecOps practices for security and observability.

[![Java Version](https://img.shields.io/badge/Java-21-blue.svg)](https://www.oracle.com/java/technologies/javase/jdk21-archive-downloads.html)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.4.1-brightgreen.svg)](https://spring.io/projects/spring-boot)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

---

## Core Features

- **Financial Operations**: Secure user registration, authentication, and real-time balance management. Supports deposits, withdrawals, and peer-to-peer transfers.
- **AI Financial Assistant**: An integrated chat interface powered by Ollama (TinyLlama), providing context-aware financial insights based on account state and transaction history.
- **High Concurrency**: Leverages Java 21 virtual threads to optimize performance and scalability for concurrent banking operations.
- **Monitoring and Observability**: Pre-configured health checks and metrics via Spring Boot Actuator and Prometheus integration.
- **Infrastructure as Code**: Fully containerized environment using Docker and Docker Compose for consistent local development and production-like testing.

---

## Technical Stack

- **Backend**: Java 21, Spring Boot 3.4.1
- **Security**: Spring Security (Session-based)
- **Database**: MySQL 8.0 with Hibernate ORM
- **AI Engine**: Ollama (TinyLlama model)
- **Frontend**: Thymeleaf, HTML5, CSS3, JavaScript
- **Observability**: Spring Boot Actuator, Micrometer, Prometheus
- **Environment**: Docker, Docker Compose

---

## Getting Started

### Prerequisites

- Docker Engine
- Docker Compose

### Quick Start with Docker

1. Clone the repository and navigate to the root directory.
2. Execute the following command to start the application and its dependencies:
   ```bash
   docker-compose up -d
   ```
3. Access the application at `http://localhost:8080`.
4. Note: On the initial startup, the AI assistant may require a few minutes to pull the necessary model within the Ollama container.

---

## Manual Installation

To run the application locally without Docker, ensure the following components are installed:

- JDK 21
- MySQL 8.0
- Ollama (installed and running with the `tinyllama` model)

### Setup Steps

1. **Database Configuration**: Create a MySQL database named `bankappdb`.
2. **Configuration**: Update `src/main/resources/application.properties` with your MySQL credentials.
3. **Initialize AI Model**:
   ```bash
   ollama run tinyllama
   ```
4. **Build and Execute**:
   ```bash
   ./mvnw spring-boot:run
   ```

---

## AI Assistant Architecture

The banking assistant provides personalized financial support by analyzing the following user context:
- Current account balance
- Detailed transaction history (most recent 5 records)
- Basic account metadata

This integration allows the assistant to provide precise answers regarding spending habits, recent activity, and account status.

---

## Observability and Management

The application exposes the following management endpoints for monitoring:

- **Health Status**: `http://localhost:8080/actuator/health`
- **Application Metrics**: `http://localhost:8080/actuator/metrics`
- **Prometheus Metrics**: `http://localhost:8080/actuator/prometheus`

---

## Project Structure

```text
src/main/java/com/example/bankapp/
├── config/        # Security and application configurations
├── controller/    # Web and REST controllers
├── model/         # JPA Entities and Data models
├── repository/    # Data access layer
└── service/       # Business logic and AI integration
```

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

<div align="center">

If you find this repository helpful, don't forget to give it a Star!

**Happy Learning!**

**TrainWithShubham**

</div>
