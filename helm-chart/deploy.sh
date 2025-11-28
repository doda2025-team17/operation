#!/bin/bash

set -e

echo "Creating shared data directory..."
mkdir -p ./shared

echo "Deploying Team17 application to Kubernetes..."

# Deploy using Helm with configurable values
helm upgrade --install team17-app . \
  --set config.appHostname=app.team17.local \
  --set-string model.modelUrl="https://github.com/doda2025-team17/model-service/releases/download/v1.0.0/model-artifacts.tar.gz" \
  --set-string app.githubToken="$GITHUB_TOKEN" \
  --atomic \
  --timeout 10m \
  --wait

echo "Deployment completed successfully!"
echo ""
echo "To access the application:"
echo "1. Add to your /etc/hosts: 192.168.56.100 app.team17.local"
echo "2. Visit: http://app.team17.local"
echo ""
echo "Check deployment status with: kubectl get pods,services,ingress"