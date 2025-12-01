# Compliance Guide for Enterprise Gateway Deployments

**Audience**: Compliance officers, Security teams, Enterprise architects  
**Purpose**: Guidance for meeting regulatory requirements (SOC2, HIPAA, GDPR, ISO 27001)  
**Scope**: Claude Code with enterprise API gateways

---

## Overview

Enterprise gateway deployments must comply with organizational and regulatory security standards. This guide covers common compliance frameworks and requirements for Claude Code gateway configurations.

**Supported Frameworks**:
- SOC 2 Type II (Security, Availability, Confidentiality)
- HIPAA (Healthcare data protection)
- GDPR (EU data protection)
- ISO 27001 (Information security management)
- PCI DSS (Payment card data - if applicable)
- FedRAMP (US federal government)

---

## 1. SOC 2 Type II Compliance

### Overview

SOC 2 is an auditing standard for service organizations that store customer data. It focuses on five Trust Service Criteria: Security, Availability, Processing Integrity, Confidentiality, and Privacy.

### Requirements for Gateway Deployment

#### CC6.1 - Logical and Physical Access Controls

**Requirement**: Implement controls to limit access to systems and data

**Implementation**:
```yaml
# Gateway access control
authentication:
  method: oauth2  # or api_key with rotation
  mfa_required: true  # For administrative access
  
authorization:
  role_based_access: true
  roles:
    - name: gateway-admin
      permissions: [read, write, delete, admin]
    - name: gateway-user
      permissions: [read]
    - name: claude-code-service
      permissions: [read, execute]

# IP allowlisting
ip_restrictions:
  enabled: true
  allowed_ranges:
    - 203.0.113.0/24  # Corporate network
    - 198.51.100.0/24 # VPN range
```

**Evidence for Auditor**:
- [ ] Access control policy documented
- [ ] Role-based access control (RBAC) configured
- [ ] IP allowlisting implemented
- [ ] Multi-factor authentication enabled for admins
- [ ] Access logs showing successful authorization checks

#### CC6.6 - System Monitoring and Audit Logging

**Requirement**: Monitor systems and maintain audit trails

**Implementation**:
```yaml
# Audit logging configuration
logging:
  enabled: true
  retention_days: 2555  # 7 years minimum for SOC 2
  log_level: INFO
  
  # What to log
  events:
    - authentication_attempts  # Success and failures
    - authorization_decisions
    - api_requests  # Method, endpoint, status, user
    - configuration_changes
    - token_creation_revocation
    - rate_limit_events
    - error_events
  
  # Where to log
  destinations:
    - type: syslog
      server: siem.example.com
    - type: s3
      bucket: audit-logs-prod
      encryption: AES-256
      immutable: true  # WORM storage
    - type: splunk
      endpoint: https://splunk.example.com

# Monitoring alerts
alerts:
  - name: auth_failure_spike
    condition: rate(auth_failures) > 10/min
    notify: security-team@example.com
  
  - name: unusual_traffic
    condition: requests > 300% baseline
    notify: ops-team@example.com
```

**Evidence for Auditor**:
- [ ] Audit logging enabled for all security-relevant events
- [ ] Logs retained for 7+ years
- [ ] Log integrity protected (immutable storage)
- [ ] Log review procedures documented
- [ ] Alerting configured for security events
- [ ] Sample audit logs showing required fields

#### CC6.7 - System Vulnerability Management

**Requirement**: Identify and remediate system vulnerabilities

**Implementation**:
```bash
# Regular vulnerability scanning
# Run weekly with Trivy, Snyk, or similar

# Container image scanning
trivy image your-gateway:latest --severity CRITICAL,HIGH

# Dependency scanning
snyk test --file=requirements.txt --severity-threshold=high

# OWASP ZAP for API security testing
zap-cli quick-scan https://gateway.example.com

# Regular patching schedule
# - Critical vulnerabilities: Within 7 days
# - High vulnerabilities: Within 30 days
# - Medium vulnerabilities: Within 90 days
```

**Evidence for Auditor**:
- [ ] Vulnerability scanning policy documented
- [ ] Regular scan schedule (weekly minimum)
- [ ] Patching SLA documented (7/30/90 days)
- [ ] Scan reports showing remediation
- [ ] Exception process for non-patchable vulns

#### CC7.2 - Encryption in Transit

**Requirement**: Encrypt data in transit using TLS 1.2+

**Implementation**:
```nginx
# Nginx TLS configuration
server {
    listen 443 ssl http2;
    
    # TLS 1.2+ only
    ssl_protocols TLSv1.2 TLSv1.3;
    
    # Strong cipher suites
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    
    # HSTS (force HTTPS)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Certificate from trusted CA
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
}
```

**Evidence for Auditor**:
- [ ] TLS 1.2+ enforced (TLS 1.0/1.1 disabled)
- [ ] Strong cipher suites configured
- [ ] Valid certificates from trusted CA
- [ ] HSTS enabled
- [ ] Certificate expiration monitoring

#### CC8.1 - Change Management

**Requirement**: Implement formal change management process

**Implementation**:
```yaml
# Example change request for gateway update
change_request:
  id: CHG-2025-001
  type: gateway_upgrade
  description: "Upgrade TrueFoundry gateway 1.2.0 -> 1.3.0"
  risk_level: medium
  
  testing:
    - unit_tests: passed
    - integration_tests: passed
    - security_scan: passed
    - performance_test: passed
  
  approvals:
    - security_team: approved
    - ops_team: approved
    - compliance_officer: approved
  
  rollback_plan: |
    1. Deploy previous version from container registry
    2. Restore configuration from backup
    3. Verify functionality with smoke tests
  
  deployment:
    scheduled: "2025-12-05T02:00:00Z"
    window: 2_hours
    notification_sent: true
```

**Evidence for Auditor**:
- [ ] Change management policy documented
- [ ] Change requests for all production changes
- [ ] Testing procedures before deployment
- [ ] Approval workflows enforced
- [ ] Rollback procedures documented and tested

---

## 2. HIPAA Compliance

### Overview

HIPAA (Health Insurance Portability and Accountability Act) requires protection of Protected Health Information (PHI). If Claude Code processes PHI, the gateway deployment must be HIPAA-compliant.

### Requirements for Gateway Deployment

#### 164.312(a)(1) - Access Control

**Requirement**: Implement technical policies to restrict access to PHI

**Implementation**:
```yaml
# User-level access control
access_control:
  authentication:
    method: saml_sso  # Corporate SSO with MFA
    mfa_required: true
    session_timeout: 15_minutes
    
  authorization:
    policy: least_privilege
    roles:
      - name: clinical_user
        can_access_phi: true
        audit_level: detailed
      - name: admin_user
        can_access_phi: false
        audit_level: standard
  
  automatic_logoff:
    enabled: true
    idle_timeout: 15_minutes
```

**Evidence for Auditor**:
- [ ] Access control policy documented
- [ ] Multi-factor authentication required
- [ ] Session timeout ≤ 15 minutes
- [ ] Automatic logoff for idle sessions
- [ ] Access restricted to minimum necessary (least privilege)

#### 164.312(a)(2)(iv) - Encryption

**Requirement**: Encrypt PHI in transit and at rest

**Implementation**:
```yaml
# Encryption configuration
encryption:
  in_transit:
    protocol: TLS_1_3
    certificate_validation: required
    
  at_rest:
    algorithm: AES_256_GCM
    key_management: aws_kms  # or Google KMS, Azure Key Vault
    key_rotation: 90_days
    
  audit_logs:
    encrypted: true
    encryption: AES_256
```

**Evidence for Auditor**:
- [ ] TLS 1.2+ for all data in transit
- [ ] AES-256 encryption for data at rest
- [ ] Encryption key management (KMS)
- [ ] Key rotation every 90 days
- [ ] Audit logs encrypted

#### 164.312(b) - Audit Controls

**Requirement**: Implement hardware/software to record and examine activity

**Implementation**:
```yaml
# HIPAA audit logging
audit_logging:
  enabled: true
  retention: 7_years  # 6 years required, 7 for safety margin
  
  phi_access_events:
    - user_authentication
    - phi_data_access  # Read operations
    - phi_data_modification  # Write operations
    - phi_data_deletion
    - security_config_changes
    - access_control_changes
    
  log_fields:
    - timestamp
    - user_id
    - user_role
    - action_performed
    - resource_accessed
    - source_ip
    - result (success/failure)
    - phi_identifiers (patient_id, encounter_id)
  
  # PHI in logs must be encrypted or de-identified
  phi_in_logs: encrypted
```

**Evidence for Auditor**:
- [ ] Audit logs capture all PHI access
- [ ] Logs retained for 6+ years
- [ ] PHI in logs encrypted
- [ ] Regular log reviews documented
- [ ] Audit trail integrity protected

#### 164.312(c) - Integrity Controls

**Requirement**: Protect PHI from improper alteration or destruction

**Implementation**:
```yaml
# Data integrity
integrity_controls:
  checksums:
    enabled: true
    algorithm: SHA256
    
  versioning:
    enabled: true
    retention: 90_days
    
  backup:
    frequency: daily
    retention: 7_years
    encryption: AES_256
    offsite: true
    
  tamper_detection:
    file_integrity_monitoring: true
    alert_on_modification: true
```

**Evidence for Auditor**:
- [ ] Data integrity verification (checksums)
- [ ] Versioning and audit trails
- [ ] Regular backups (daily minimum)
- [ ] Backup encryption and offsite storage
- [ ] Tamper detection and alerting

#### 164.530(j) - Business Associate Agreement (BAA)

**Requirement**: Execute BAA with any entity that processes PHI

**Action Items**:
1. ✅ Execute BAA with Anthropic (if processing PHI)
2. ✅ Execute BAA with gateway provider (TrueFoundry, Zuplo, etc.)
3. ✅ Execute BAA with cloud provider (AWS, GCP, Azure)
4. ✅ Review BAA terms annually
5. ✅ Maintain BAA documentation

**Key BAA Terms**:
- Permitted uses and disclosures of PHI
- Safeguards to prevent unauthorized disclosure
- Reporting requirements for breaches
- Return or destruction of PHI upon termination
- Liability and indemnification

**Evidence for Auditor**:
- [ ] Signed BAA with Anthropic
- [ ] Signed BAA with gateway provider
- [ ] Signed BAA with cloud provider
- [ ] BAA review schedule documented
- [ ] BAA amendments for service changes

---

## 3. GDPR Compliance

### Overview

GDPR (General Data Protection Regulation) protects personal data of EU residents. If Claude Code processes EU personal data, GDPR compliance is required.

### Requirements for Gateway Deployment

#### Article 25 - Data Protection by Design and Default

**Requirement**: Implement data protection from the outset

**Implementation**:
```yaml
# Privacy-by-design configuration
privacy_settings:
  data_minimization:
    collect_only_necessary: true
    retention_limits: true
    
  pseudonymization:
    enabled: true  # Replace PII with pseudonyms where possible
    
  access_controls:
    role_based: true
    principle: least_privilege
```

#### Article 30 - Records of Processing Activities

**Requirement**: Maintain records of data processing

**Documentation Required**:
```markdown
# Processing Activity Record

## Controller Information
- Name: Your Organization
- Contact: dpo@example.com

## Purpose of Processing
- Purpose: LLM-assisted code generation via Claude Code
- Legal Basis: Legitimate interest (employee productivity)

## Categories of Personal Data
- User authentication data (email, username)
- Usage logs (timestamps, prompts - pseudonymized)
- IP addresses (for security purposes)

## Categories of Recipients
- Anthropic (AI model provider) - USA
- Gateway Provider (TrueFoundry/Zuplo) - EU/USA
- Cloud Provider (AWS/GCP) - EU region

## Transfers to Third Countries
- Anthropic API (USA) - Standard Contractual Clauses (SCCs) in place
- Data Processing Agreement (DPA) executed

## Retention Periods
- Authentication logs: 90 days
- Usage logs: 1 year
- Audit logs: 7 years (compliance requirement)

## Security Measures
- Encryption in transit (TLS 1.3)
- Encryption at rest (AES-256)
- Access controls and authentication
- Regular security audits
```

**Evidence for Auditor**:
- [ ] Processing activity records documented
- [ ] Legal basis for processing identified
- [ ] Data flow diagrams created
- [ ] Third-party data processors identified
- [ ] Data retention schedule documented

#### Article 32 - Security of Processing

**Requirement**: Implement appropriate technical and organizational measures

**Implementation**:
```yaml
# GDPR security measures
security_measures:
  encryption:
    in_transit: TLS_1_3
    at_rest: AES_256
    
  access_control:
    authentication: MFA
    authorization: RBAC
    
  pseudonymization:
    user_identifiers: hashed
    ip_addresses: truncated
    
  monitoring:
    security_events: logged
    anomaly_detection: enabled
    
  incident_response:
    breach_notification_procedure: documented
    notification_timeline: 72_hours
```

**Evidence for Auditor**:
- [ ] Security measures documented
- [ ] Encryption implemented (transit and rest)
- [ ] Access controls tested
- [ ] Pseudonymization/anonymization procedures
- [ ] Breach notification procedures documented

#### Article 33 & 34 - Breach Notification

**Requirement**: Notify authorities within 72 hours of breach

**Breach Response Plan**:
```markdown
# Data Breach Response Plan

## Step 1: Detection (0-2 hours)
- Security monitoring alerts
- Anomaly detection triggers
- User reports

## Step 2: Containment (2-4 hours)
- Isolate affected systems
- Revoke compromised credentials
- Block unauthorized access

## Step 3: Assessment (4-24 hours)
- Determine scope of breach
- Identify affected individuals
- Assess risk to data subjects

## Step 4: Notification (24-72 hours)
- Notify supervisory authority (≤72 hours)
- Notify affected individuals (if high risk)
- Document breach details

## Step 5: Remediation
- Patch vulnerabilities
- Implement additional controls
- Conduct post-incident review

## Notification Templates
- Template for supervisory authority
- Template for affected individuals
- Template for internal stakeholders
```

**Evidence for Auditor**:
- [ ] Breach response plan documented
- [ ] 72-hour notification timeline
- [ ] Breach notification templates
- [ ] Regular breach drills conducted
- [ ] Incident response team identified

#### Article 44-50 - International Data Transfers

**Requirement**: Ensure adequate safeguards for data transfers outside EU

**Implementation**:
```yaml
# Data transfer safeguards
data_transfers:
  mechanism: standard_contractual_clauses
  
  # Alternative mechanisms
  # - adequacy_decision
  # - binding_corporate_rules
  # - certification (EU-US Data Privacy Framework)
  
  suppliers:
    - name: Anthropic
      location: USA
      safeguard: SCCs
      dpa_executed: true
      
    - name: Gateway Provider
      location: EU
      safeguard: EU_based (no transfer)
```

**Required Documents**:
- [ ] Standard Contractual Clauses (SCCs) with Anthropic
- [ ] Data Processing Agreement (DPA) with gateway provider
- [ ] Data transfer impact assessment (DTIA)
- [ ] Supplementary measures documentation

---

## 4. ISO 27001 Compliance

### Overview

ISO 27001 is an international standard for information security management systems (ISMS).

### Key Controls for Gateway Deployment

#### A.9 - Access Control

```yaml
# Access control policy
access_control:
  user_registration:
    approval_required: true
    approver: security_team
    
  privileged_access:
    mfa_required: true
    session_recording: true
    
  password_policy:
    min_length: 12
    complexity: true
    expiration: 90_days
```

#### A.12 - Operations Security

```yaml
# Operations security
operations:
  change_management:
    required_for: all_production_changes
    approval_workflow: true
    
  capacity_management:
    monitoring: enabled
    alerts: configured
    
  malware_protection:
    antivirus: enabled
    scanning: real_time
```

#### A.18 - Compliance

```yaml
# Compliance monitoring
compliance:
  legal_requirements:
    - GDPR
    - HIPAA (if applicable)
    - SOC2
    
  compliance_reviews:
    frequency: quarterly
    auditor: external
    
  non_compliance_handling:
    reporting: mandatory
    remediation_timeline: 30_days
```

---

## 5. Compliance Checklist

### General Requirements

- [ ] **Data Classification**: PHI, PII, confidential data identified
- [ ] **Vendor Due Diligence**: Gateway provider assessed for compliance
- [ ] **Contracts**: BAA/DPA executed with all data processors
- [ ] **Policies**: Security and privacy policies documented
- [ ] **Training**: All users trained on compliance requirements
- [ ] **Audits**: Regular compliance audits scheduled
- [ ] **Incident Response**: Breach notification procedures documented

### Technical Controls

- [ ] **Encryption**: TLS 1.2+ in transit, AES-256 at rest
- [ ] **Authentication**: MFA enabled for privileged access
- [ ] **Authorization**: RBAC with least privilege
- [ ] **Audit Logging**: Comprehensive logs with 7-year retention
- [ ] **Vulnerability Management**: Regular scans and patching
- [ ] **Data Retention**: Retention schedule documented and enforced
- [ ] **Backup & Recovery**: Regular backups tested

### Documentation

- [ ] **Data Flow Diagrams**: Visual representation of data flows
- [ ] **Risk Assessment**: Documented for gateway deployment
- [ ] **Privacy Impact Assessment**: Completed for GDPR
- [ ] **Security Architecture**: Gateway security design documented
- [ ] **Runbooks**: Incident response and operations procedures
- [ ] **Evidence Collection**: Audit artifacts organized and accessible

---

## 6. Audit Preparation

### Documents to Prepare

1. **Architecture Diagrams**: Gateway topology, data flows
2. **Configuration Exports**: Gateway settings (redact secrets)
3. **Access Control Policies**: RBAC roles and permissions
4. **Audit Log Samples**: Showing required events logged
5. **Vulnerability Scan Reports**: Latest security assessments
6. **Penetration Test Results**: If applicable
7. **Incident Response Plan**: With breach notification procedures
8. **Change Management Records**: Last 12 months
9. **Training Records**: User compliance training completion
10. **Vendor Assessments**: Due diligence on gateway provider

### Common Auditor Questions

**Q**: How do you ensure only authorized users access the gateway?  
**A**: Multi-factor authentication, role-based access control, IP allowlisting, session timeouts

**Q**: How long are audit logs retained?  
**A**: 7 years in encrypted, immutable storage (S3 with Object Lock)

**Q**: What happens if the gateway provider has a data breach?  
**A**: Incident response plan triggers, breach notification within 72 hours (GDPR), vendor responsible per BAA/DPA

**Q**: How do you protect data in transit?  
**A**: TLS 1.3 with strong cipher suites, certificate validation, HSTS enabled

**Q**: How often do you rotate credentials?  
**A**: API keys every 90 days, OAuth tokens every 15-60 minutes, service account keys every 90 days

---

## 7. Additional Resources

- **HIPAA Security Rule**: https://www.hhs.gov/hipaa/for-professionals/security/index.html
- **GDPR Official Text**: https://gdpr-info.eu/
- **SOC 2 Guide**: AICPA Trust Services Criteria
- **ISO 27001**: ISO/IEC 27001:2022 standard
- **NIST Cybersecurity Framework**: https://www.nist.gov/cyberframework
- **Security Best Practices**: `examples/us2-security-best-practices.md`
- **Enterprise Integration**: `examples/us2-enterprise-integration.md`
