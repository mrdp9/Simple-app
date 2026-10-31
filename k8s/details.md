## Frontend:
Stack: nginx > react
nginx port: 80
API Auth service port: 4000
url: http://auth-service:4000/

## Auth Service:
Base image: node:20-slim
port: 4000
url: http://auth-service:4000/

## Data Service:
stack: python
image i'll use: slim:latest
Data Service port: 8000
url:  http://data-service:8000/
