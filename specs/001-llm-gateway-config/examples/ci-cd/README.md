# CI/CD Configuration Examples

This directory contains example CI/CD pipeline configurations for deploying and testing LiteLLM gateway in various CI/CD environments.

## Available Examples

### GitHub Actions

- **File**: `github-actions.yml`
- **Usage**: Copy to `.github/workflows/litellm-gateway.yml`
- **Features**:
  - Configuration validation
  - Gateway health checks
  - Model availability testing
  - Staging and production deployments

### GitLab CI

- **File**: `gitlab-ci.yml`
- **Usage**: Copy to `.gitlab-ci.yml` or include in your existing pipeline
- **Features**:
  - Multi-stage pipeline (validate, test, deploy)
  - Google Cloud authentication
  - Manual deployment gates

### Jenkins Pipeline

- **File**: `jenkins-pipeline.groovy`
- **Usage**: Create a new Jenkins Pipeline job and paste this script
- **Features**:
  - Credential management
  - Background gateway testing
  - Conditional deployments

## Prerequisites

All CI/CD examples require:

1. **Google Cloud Authentication**:
   - GitHub Actions: Use `google-github-actions/auth@v2` with `GCP_SA_KEY` secret
   - GitLab CI: Set `GCP_SA_KEY` as a CI/CD variable (base64 encoded)
   - Jenkins: Configure GCP service account credentials in Jenkins

2. **Python Dependencies**:
   - `litellm` - LiteLLM gateway library
   - `google-cloud-aiplatform` - Google Cloud AI Platform SDK
   - `pyyaml` - YAML parsing

3. **Configuration File**:
   - Place your `litellm.yaml` configuration in `config/litellm.yaml`
   - Ensure all required environment variables are set in CI/CD secrets

## Customization

### Environment Variables

All examples use these default values:

- `LITELLM_PORT`: `4000`
- `PYTHON_VERSION`: `3.9`

Modify these in your pipeline configuration as needed.

### Deployment Steps

The deployment stages (`deploy-staging`, `deploy-production`) are placeholders. Replace with your actual deployment commands:

**Kubernetes Example**:

```bash
kubectl apply -f k8s/gateway-deployment.yaml
kubectl rollout status deployment/litellm-gateway
```

**Terraform Example**:

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

**Docker Example**:

```bash
docker build -t litellm-gateway:latest .
docker push litellm-gateway:latest
kubectl set image deployment/litellm-gateway litellm-gateway=litellm-gateway:latest
```

## Security Best Practices

1. **Secrets Management**:
   - Never commit credentials to version control
   - Use CI/CD secret management (GitHub Secrets, GitLab Variables, Jenkins Credentials)
   - Rotate service account keys regularly

2. **Least Privilege**:
   - Grant minimal permissions to CI/CD service accounts
   - Use separate accounts for staging and production

3. **Audit Logging**:
   - Enable audit logs for all deployments
   - Monitor for unauthorized access

## Troubleshooting

### Gateway Health Check Fails

- Verify Google Cloud authentication is working
- Check that the gateway port is not already in use
- Ensure all required environment variables are set
- Review gateway logs for errors

### Model Availability Test Fails

- Verify GCP project has access to the models
- Check quota limits in GCP Console
- Ensure correct region configuration in `litellm.yaml`

### Deployment Failures

- Verify deployment credentials have sufficient permissions
- Check network connectivity to deployment target
- Review deployment logs for specific error messages

## Additional Resources

- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Google Cloud AI Platform](https://cloud.google.com/vertex-ai/docs)
- [Gateway Configuration Guide](../README.md)
