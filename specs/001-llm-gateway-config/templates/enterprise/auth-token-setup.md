# Authentication Token Setup for Enterprise Gateways

**Purpose**: Guide for setting up authentication tokens and credentials for enterprise gateway access  
**Audience**: Platform engineers, DevOps, Security teams  
**Prerequisites**: Enterprise gateway deployed and accessible

---

## Overview

Enterprise gateways require authentication to validate client requests before forwarding to the Anthropic API. This guide covers authentication setup patterns for different gateway types and enterprise requirements.

---

## Authentication Flow

```
┌──────────────┐         ┌────────────────────┐         ┌──────────────────┐
│ Claude Code  │─────────│ Enterprise Gateway │─────────│  Anthropic API   │
└──────────────┘         └────────────────────┘         └──────────────────┘
      │                           │                              │
      │  1. Request +             │                              │
      │     Gateway Token         │                              │
      │─────────────────────────▶│                              │
      │                           │  2. Validate Token           │
      │                           │        (Gateway Auth)        │
      │                           │                              │
      │                           │  3. Forward Request +        │
      │                           │     Provider API Key         │
      │                           │─────────────────────────────▶│
      │                           │                              │
      │                           │  4. Response                 │
      │                           │◀─────────────────────────────│
      │  5. Response              │                              │
      │◀─────────────────────────│                              │
```

**Key Points**:

- Client authenticates with gateway using **gateway token**
- Gateway authenticates with Anthropic using **provider API key**
- Gateway never exposes provider API key to client
- Gateway tracks usage per client/team using gateway token

---

## Authentication Pattern 1: API Key (Bearer Token)

**Use Case**: Simple authentication for internal teams  
**Security Level**: Medium  
**Complexity**: Low

### Setup Steps

#### Step 1: Generate Gateway API Key

**For LiteLLM**:

```bash
# Generate master key
export LITELLM_MASTER_KEY=$(openssl rand -hex 32)

# Start LiteLLM with master key
litellm --config litellm-config.yaml \
  --port 4000 \
  --master-key $LITELLM_MASTER_KEY
```

**For TrueFoundry**:

```bash
# Generate API key in TrueFoundry Console
# Settings → API Keys → Create API Key
# Copy key: tfk_xxxxxxxxxxxxxxxxxxxxx
```

**For Zuplo**:

```bash
# Generate API key in Zuplo Portal
# Settings → API Keys → Create API Key
# Select "Public Key" type
# Copy key: zpka_xxxxxxxxxxxxxxxxxxxxx
```

**For Custom Gateway** (example with Kong):

```bash
# Create consumer
curl -X POST http://localhost:8001/consumers \
  --data "username=claude-code-user"

# Create API key for consumer
curl -X POST http://localhost:8001/consumers/claude-code-user/key-auth \
  --data "key=custom-gateway-api-key-xxxxx"
```

#### Step 2: Configure Claude Code

```bash
# Set gateway URL and token
export ANTHROPIC_BASE_URL="https://your-gateway.example.com"
export ANTHROPIC_AUTH_TOKEN="your-gateway-api-key"

# Verify configuration
claude /status
```

#### Step 3: Test Authentication

```bash
# Test request
claude "Hello world"

# Expected: Successful response from Anthropic via gateway
# If authentication fails: 401 Unauthorized error
```

### Security Best Practices

- ✅ Store API keys in environment variables, not config files
- ✅ Use separate API keys for dev/staging/production
- ✅ Rotate API keys every 90 days
- ✅ Implement key expiration policies
- ✅ Log all authentication attempts
- ❌ Never commit API keys to version control
- ❌ Never share API keys via email or chat
- ❌ Never hardcode API keys in source code

---

## Authentication Pattern 2: OAuth 2.0 (Enterprise)

**Use Case**: Enterprise SSO integration with corporate identity provider  
**Security Level**: High  
**Complexity**: High

### Setup Steps

#### Step 1: Configure OAuth Provider

**Example with Okta**:

```bash
# Create OAuth 2.0 Application in Okta
# Application Type: Web Application
# Grant Types: Authorization Code, Client Credentials
# Redirect URIs: https://your-gateway.example.com/oauth/callback
# Scopes: anthropic:read, anthropic:write
```

#### Step 2: Configure Gateway OAuth Integration

**For Zuplo** (routes.oas.json):

```json
{
  "security": [
    {
      "oauth2": ["anthropic:read", "anthropic:write"]
    }
  ],
  "securityDefinitions": {
    "oauth2": {
      "type": "oauth2",
      "authorizationUrl": "https://your-org.okta.com/oauth2/v1/authorize",
      "tokenUrl": "https://your-org.okta.com/oauth2/v1/token",
      "flow": "accessCode",
      "scopes": {
        "anthropic:read": "Read access to Anthropic API",
        "anthropic:write": "Write access to Anthropic API"
      }
    }
  }
}
```

**For Custom Gateway** (example with Kong + OIDC):

```yaml
plugins:
  - name: oidc
    config:
      client_id: your-client-id
      client_secret: your-client-secret
      discovery: https://your-org.okta.com/.well-known/openid-configuration
      scope: openid email profile anthropic
      token_endpoint_auth_method: client_secret_post
```

#### Step 3: Obtain OAuth Token

**Authorization Code Flow** (interactive):

```bash
# User authenticates via browser
# Gateway redirects to OAuth provider
# User logs in with corporate credentials
# OAuth provider redirects back with authorization code
# Gateway exchanges code for access token
# Access token stored in session cookie
```

**Client Credentials Flow** (service account):

```bash
# Obtain access token
curl -X POST https://your-org.okta.com/oauth2/v1/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=your-client-id" \
  -d "client_secret=your-client-secret" \
  -d "scope=anthropic:read anthropic:write"

# Response:
# {
#   "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
#   "token_type": "Bearer",
#   "expires_in": 3600
# }

# Configure Claude Code
export ANTHROPIC_AUTH_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

#### Step 4: Token Refresh (when expired)

```bash
# Refresh access token
curl -X POST https://your-org.okta.com/oauth2/v1/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "client_id=your-client-id" \
  -d "client_secret=your-client-secret" \
  -d "refresh_token=your-refresh-token"
```

### Security Best Practices

- ✅ Use PKCE (Proof Key for Code Exchange) for authorization code flow
- ✅ Validate JWT signatures and claims
- ✅ Implement token refresh before expiration
- ✅ Use short-lived access tokens (15-60 minutes)
- ✅ Store refresh tokens securely (encrypted at rest)
- ✅ Revoke tokens on user logout
- ❌ Never log access tokens or refresh tokens
- ❌ Never share client secrets in client-side code

---

## Authentication Pattern 3: Service Account (GCP)

**Use Case**: Automated systems accessing Vertex AI through gateway  
**Security Level**: High  
**Complexity**: Medium

### Setup Steps

#### Step 1: Create GCP Service Account

```bash
# Create service account
gcloud iam service-accounts create claude-code-gateway \
  --display-name="Claude Code Gateway Service Account" \
  --description="Service account for Claude Code to access Vertex AI via gateway"

# Grant required roles
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:claude-code-gateway@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

# Generate service account key
gcloud iam service-accounts keys create claude-code-gateway-key.json \
  --iam-account=claude-code-gateway@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

#### Step 2: Configure Gateway

**For LiteLLM**:

```bash
# Set service account key path
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/claude-code-gateway-key.json"

# Configure LiteLLM to use service account
# (litellm-config.yaml)
model_list:
  - model_name: gemini-2.5-flash
    litellm_params:
      model: vertex_ai/gemini-2.5-flash
      vertex_project: YOUR_PROJECT_ID
      vertex_location: us-central1
      # LiteLLM automatically uses GOOGLE_APPLICATION_CREDENTIALS
```

#### Step 3: Configure Claude Code

```bash
export ANTHROPIC_BASE_URL="https://your-gateway.example.com"
export ANTHROPIC_AUTH_TOKEN="your-gateway-api-key"  # Gateway key, not GCP key

# Gateway handles GCP authentication using service account
# Claude Code doesn't need direct GCP credentials
```

### Security Best Practices

- ✅ Use least-privilege IAM roles (roles/aiplatform.user only)
- ✅ Rotate service account keys every 90 days
- ✅ Store service account keys in secret manager
- ✅ Use Workload Identity for GKE deployments (avoid keys)
- ✅ Enable audit logging for service account usage
- ❌ Never commit service account keys to version control
- ❌ Never share service account keys across environments
- ❌ Never grant Owner or Editor roles to service accounts

---

## Authentication Pattern 4: Mutual TLS (mTLS)

**Use Case**: High-security environments requiring certificate-based authentication  
**Security Level**: Very High  
**Complexity**: High

### Setup Steps

#### Step 1: Generate Client Certificate

```bash
# Generate private key
openssl genrsa -out client.key 4096

# Generate certificate signing request (CSR)
openssl req -new -key client.key -out client.csr \
  -subj "/C=US/ST=CA/L=SanFrancisco/O=YourOrg/CN=claude-code-client"

# Sign CSR with your CA (or use self-signed for testing)
openssl x509 -req -in client.csr \
  -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out client.crt \
  -days 365 -sha256
```

#### Step 2: Configure Gateway for mTLS

**For Nginx**:

```nginx
server {
    listen 443 ssl;
    server_name gateway.example.com;
    
    # Server certificate
    ssl_certificate /path/to/server.crt;
    ssl_certificate_key /path/to/server.key;
    
    # Client certificate verification
    ssl_client_certificate /path/to/ca.crt;
    ssl_verify_client on;
    ssl_verify_depth 2;
    
    location /v1/messages {
        # Extract client identity from certificate
        set $client_dn $ssl_client_s_dn;
        
        # Forward to Anthropic with provider key
        proxy_pass https://api.anthropic.com;
        proxy_set_header Authorization "Bearer sk-ant-api03-xxxxx";
        proxy_set_header X-Client-DN $client_dn;
    }
}
```

#### Step 3: Configure Claude Code

```bash
# Set gateway URL
export ANTHROPIC_BASE_URL="https://gateway.example.com"

# Set client certificate and key
export SSL_CERT_FILE="/path/to/client.crt"
export SSL_KEY_FILE="/path/to/client.key"

# Set CA certificate for server verification
export SSL_CAFILE="/path/to/ca.crt"

# Test connection
claude /status
```

### Security Best Practices

- ✅ Use strong key sizes (4096-bit RSA or 256-bit ECC)
- ✅ Set short certificate validity periods (30-90 days)
- ✅ Implement certificate revocation (CRL or OCSP)
- ✅ Store private keys in hardware security modules (HSM)
- ✅ Monitor certificate expiration dates
- ❌ Never share private keys
- ❌ Never use self-signed certificates in production
- ❌ Never disable certificate verification

---

## Token Storage Best Practices

### Environment Variables (Development)

```bash
# .bashrc or .zshrc
export ANTHROPIC_BASE_URL="https://gateway.example.com"
export ANTHROPIC_AUTH_TOKEN="your-gateway-api-key"
```

### Secret Managers (Production)

**AWS Secrets Manager**:

```bash
# Store secret
aws secretsmanager create-secret \
  --name claude-code/gateway-token \
  --secret-string "your-gateway-api-key"

# Retrieve secret in application
TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id claude-code/gateway-token \
  --query SecretString --output text)
export ANTHROPIC_AUTH_TOKEN="$TOKEN"
```

**Google Secret Manager**:

```bash
# Store secret
echo -n "your-gateway-api-key" | gcloud secrets create claude-code-gateway-token \
  --data-file=-

# Retrieve secret
export ANTHROPIC_AUTH_TOKEN=$(gcloud secrets versions access latest \
  --secret="claude-code-gateway-token")
```

**HashiCorp Vault**:

```bash
# Store secret
vault kv put secret/claude-code gateway_token="your-gateway-api-key"

# Retrieve secret
export ANTHROPIC_AUTH_TOKEN=$(vault kv get -field=gateway_token secret/claude-code)
```

### Password Managers (Individual Developers)

- **1Password CLI**:

  ```bash
  export ANTHROPIC_AUTH_TOKEN=$(op read "op://Private/Claude Gateway/token")
  ```

- **LastPass CLI**:

  ```bash
  export ANTHROPIC_AUTH_TOKEN=$(lpass show --password "Claude Gateway Token")
  ```

---

## Token Rotation Procedures

### Manual Rotation

```bash
# 1. Generate new API key in gateway console
NEW_TOKEN="new-gateway-api-key-xxxxx"

# 2. Test new token
ANTHROPIC_AUTH_TOKEN="$NEW_TOKEN" claude /status

# 3. If successful, update production
export ANTHROPIC_AUTH_TOKEN="$NEW_TOKEN"

# 4. Revoke old token in gateway console
# 5. Update secret manager with new token
# 6. Verify all clients using new token
```

### Automated Rotation (Recommended)

**AWS Lambda Example**:

```python
import boto3
import requests

def rotate_gateway_token(event, context):
    # Generate new token from gateway API
    response = requests.post(
        "https://gateway.example.com/api/keys",
        json={"name": "claude-code-rotated"},
        headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}
    )
    new_token = response.json()["key"]
    
    # Update AWS Secrets Manager
    secrets_client = boto3.client('secretsmanager')
    secrets_client.update_secret(
        SecretId='claude-code/gateway-token',
        SecretString=new_token
    )
    
    # Revoke old token after grace period (e.g., 24 hours)
    # Schedule revocation via CloudWatch Events
    
    return {"statusCode": 200, "body": "Token rotated successfully"}
```

---

## Troubleshooting

### Issue: 401 Unauthorized

**Symptoms**: `401 Unauthorized` error when making requests

**Possible Causes**:

1. Invalid or expired gateway token
2. Token not sent in correct header format
3. Gateway configuration error

**Solutions**:

```bash
# 1. Verify token is set
echo $ANTHROPIC_AUTH_TOKEN

# 2. Test token directly
curl -H "Authorization: Bearer $ANTHROPIC_AUTH_TOKEN" \
  https://your-gateway.example.com/v1/health

# 3. Regenerate token if expired
# See gateway documentation for token regeneration

# 4. Check token format
# LiteLLM: Any string (e.g., "sk-xxxxx")
# TrueFoundry: Starts with "tfk_"
# Zuplo: Starts with "zpka_"
```

### Issue: 403 Forbidden

**Symptoms**: `403 Forbidden` error despite valid authentication

**Possible Causes**:

1. Token lacks required permissions/scopes
2. IP allowlist blocking request
3. Gateway policy denying access

**Solutions**:

```bash
# 1. Check token permissions in gateway console
# 2. Verify IP address is allowed
# 3. Review gateway access logs for denial reason
# 4. Contact gateway administrator to grant access
```

### Issue: Token Expiration

**Symptoms**: Authentication works intermittently, fails after some time

**Solutions**:

```bash
# Implement token refresh
# For OAuth: Use refresh token to obtain new access token
# For API Keys: Rotate before expiration date
# For JWT: Check exp claim and refresh before expiration
```

---

## Additional Resources

- **LiteLLM Authentication**: https://docs.litellm.ai/docs/proxy/virtual_keys
- **OAuth 2.0 Specification**: https://oauth.net/2/
- **GCP Service Accounts**: https://cloud.google.com/iam/docs/service-accounts
- **mTLS Guide**: https://en.wikipedia.org/wiki/Mutual_authentication
- **AWS Secrets Manager**: https://aws.amazon.com/secrets-manager/
- **Google Secret Manager**: https://cloud.google.com/secret-manager
- **HashiCorp Vault**: https://www.vaultproject.io/
