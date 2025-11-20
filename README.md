# Operation

This organization contains a machine learning-based SMS spam detection system with a web interface.

## Architecture Overview

This system has four repositories, found at these links:

- **app** (link): Spring Boot web application as the frontend and acting as an API gateway
- **model-service** (link): Python-based machine learning service for spam detection
- **lib-version** (link): Version utility library (used by app)
- **operation** (link): Main deployment and orchestration repository with documentation

## Quick Start
### Prerequisites
- Docker
- Docker Compose

### Running the Application

1. **Clone the operation repository**:
   ```bash
   git clone https://github.com/doda2025-team17/operation.git
   cd operation
   ```

2. **Start the Services**:
    ```
    docker-compose up -d
    ```

3. **Access the Application**:
    Access the Web Application at: http://localhost:8080/

    Access the Model Service API at: http://model-service:8081/

4. **Stop the Services**:
    ```
    docker-compose down
    ```

## Configuration

### Environment Variables
1. **app**: 
- `SERVER_PORT`: Port for the Spring Boot application (default: `8080`)
- `MODEL_HOST`: URL of the model-service (default: `http://model-service:8081`)

2. **model-service**:
- `PORT`: Port for the Python model service (default: `8081`)

### Port Mapping
1. **app**: Host has port `8080`. The container also has port `8080`.
2. **model-service**: Host has port `8081`. The container also has port `8081`.

## Assignments

### Assignment 1
For Assignment 1, we have implemented ... . More information on ... can be found at ... .