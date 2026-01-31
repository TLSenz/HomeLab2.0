# Homelab Automation Documentation

## Overview

This repository implements a sophisticated webhook-driven automation system for managing NixOS configurations across multiple servers in a homelab environment. The system supports role-based deployments, automated backups, and integration with Terraform infrastructure changes.

## Architecture

### Core Components

1. **Role-Based Configuration System**
   - Predefined roles bundle multiple services
   - Flexible service-level configuration still supported
   - Dynamic configuration loading based on webhook data

2. **Webhook-Driven Deployment**
   - GitHub Actions workflows triggered by repository dispatch events
   - Tailscale integration for secure server connectivity
   - SSH key management via GitHub Secrets

3. **Automated Backup System**
   - Pre-deployment backups to prevent data loss
   - Configurable backup types and retention policies
   - Artifact storage and integrity verification

4. **Terraform Integration**
   - Automatic NixOS updates when infrastructure changes
   - Intelligent change detection and analysis
   - Coordinated infrastructure and configuration updates

## Directory Structure

```
HomeLab/
├── .github/workflows/
│   ├── deploy.yaml          # Main deployment workflow
│   ├── backup.yaml          # Backup automation
│   └── terraform-sync.yaml  # Terraform integration
├── nixos/
│   ├── flake.nix            # Main NixOS configuration
│   ├── roles/               # Role definitions
│   │   ├── web-server.nix   # Web server role
│   │   ├── database-server.nix # Database role
│   │   ├── full-stack.nix   # Web + Database
│   │   ├── storage-server.nix # File sharing role
│   │   └── backup-server.nix # Backup server role
│   ├── modules/
│   │   └── services/        # Individual service modules
│   │   ├── webserver.nix
│   │   └── database.nix
│   ├── hosts/               # Machine-specific configs
│   │   ├── node-a/
│   │   └── node-b/
│   ├── common/
│   │   └── global.nix       # Shared configuration
│   └── modules/             # Service modules
│       ├── immich.nix       # Photo management
│       ├── nextcloud.nix    # Cloud storage
│       ├── vaultwarden.nix  # Password manager
│       └── gitlab.nix       # Git hosting
├── aws-lambda/              # Inventory management
└── docs/
    └── README.md            # This documentation
```

## Available Roles

### 1. web-server
- **Services**: Nginx web server
- **Ports**: 80, 443
- **Features**: 
  - SSL/HTTPS support (via certbot)
  - Log rotation
  - Performance optimization
  - Reverse proxy capabilities

### 2. database-server
- **Services**: PostgreSQL
- **Ports**: 5432
- **Features**:
  - Automated backups
  - Performance tuning
  - Remote access control
  - Initial database setup

### 3. full-stack
- **Services**: Nginx + PostgreSQL + Node.js
- **Ports**: 80, 443, 5432
- **Features**:
  - Complete web application stack
  - API proxy configuration
  - Database connectivity
  - Development tools

### 4. storage-server
- **Services**: Samba, NFS
- **Ports**: 139, 445, 2049
- **Features**:
  - File sharing (SMB/CIFS)
  - Network File System (NFS)
  - Public and private shares
  - User access control

### 5. backup-server
- **Services**: Restic, BorgBackup, Grafana, Prometheus
- **Ports**: 3000, 9100
- **Features**:
  - Multiple backup solutions
  - Monitoring dashboards
  - Automated backup scheduling
  - Retention policies

## Existing Service Modules

The system includes pre-configured modules for popular homelab services:

- **Nextcloud**: Cloud storage and file synchronization
- **Immich**: Photo and video management
- **Vaultwarden**: Bitwarden-compatible password manager
- **Gitlab**: Git repository hosting and CI/CD

## Webhook Payload Structure

### Role-Based Deployment
```json
{
  "machines": [
    {
      "host": "100.64.0.1",
      "config": "node-a",
      "role": "web-server",
      "mode": "switch"
    }
  ]
}
```

### Service-Based Deployment (Legacy Support)
```json
{
  "machines": [
    {
      "host": "100.64.0.1",
      "config": "node-a",
      "services": ["web", "db"],
      "mode": "switch"
    }
  ]
}
```

### Terraform Integration Payload
```json
{
  "repo": "your-terraform-repo",
  "resources": [
    {
      "type": "proxmox_vm_qemu",
      "attributes": {
        "public_ip": "100.64.0.1",
        "name": "web-server-1",
        "role": "web-server"
      }
    }
  ]
}
```

## Workflow Descriptions

### 1. Main Deployment Workflow (deploy.yaml)

**Triggers**: 
- Repository dispatch with `deploy-fleet` event type

**Process**:
1. Parse webhook payload for machine configurations
2. Generate deployment configuration JSON
3. Connect to Tailscale for secure networking
4. Deploy NixOS configurations to target machines
5. Perform post-deployment validation

**Environment Variables**:
- `SSH_PRIVATE_KEY`: GitHub secret for SSH access
- `TAILSCALE_AUTHKEY`: GitHub secret for Tailscale
- `GITHUB_EVENT_CLIENT_PAYLOAD`: Complete webhook data

### 2. Backup Workflow (backup.yaml)

**Triggers**:
- Push to main branch
- Manual workflow dispatch

**Process**:
1. Connect to target servers via Tailscale
2. Create system configuration backups
3. Backup user data and service data
4. Verify backup integrity
5. Store as GitHub artifacts

**Backup Contents**:
- `/etc` - System configuration
- `/etc/nixos` - NixOS configuration
- `/home` - User data
- `/var/lib` - Service data

### 3. Terraform Sync Workflow (terraform-sync.yaml)

**Triggers**:
- Repository dispatch with `terraform-changed` event
- Manual workflow dispatch

**Process**:
1. Analyze Terraform resource changes
2. Determine if NixOS updates are required
3. Trigger pre-deployment backups if needed
4. Deploy updated configurations to affected machines
5. Update monitoring and status systems

## AWS Lambda Inventory Management

The homelab includes an AWS Lambda-based inventory system for tracking resources:

- **GET Function**: Retrieve current inventory
- **POST Function**: Add or modify inventory items
- **Integration**: Acts as source of truth for CI/CD decisions

## Terraform Integration

### Infrastructure Layer
- Deploy VMs to Proxmox
- Initialize with Cloud-Init
- Apply network configurations
- Tag resources for CI/CD recognition

### CI/CD Pipeline
1. Connect to Tailscale network
2. SSH into target servers
3. Create data backups
4. Install/Update NixOS
5. Apply role-based configurations

## Configuration Variables

### Required GitHub Secrets
- `SSH_PRIVATE_KEY`: SSH private key for server access
- `TAILSCALE_AUTHKEY`: Authentication key for Tailscale
- `TS_OAUTH_CLIENT_ID`: OAuth client ID for Tailscale
- `TS_OAUTH_SECRET`: OAuth secret for Tailscale

### Webhook Data Variables
- `GITHUB_EVENT_CLIENT_PAYLOAD`: Full JSON payload from webhook
- `ROLE_NAME`: Role to apply to target server
- `TARGET_HOST`: IP address of target server
- `CONFIG_NAME`: NixOS configuration identifier
- `DEPLOYMENT_MODE`: "switch", "build", or "test"

### Terraform Integration Variables
- `TERRAFORM_CHANGED`: Boolean flag indicating infrastructure changes
- `AFFECTED_RESOURCES`: JSON array of modified infrastructure resources
- `TERRAFORM_REPO`: Source repository of changes

## Usage Examples

### Deploying a Web Server
```bash
# Trigger webhook with role-based configuration
curl -X POST \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/your-username/HomeLab/dispatches \
  -d '{
    "event_type": "deploy-fleet",
    "client_payload": {
      "machines": [
        {
          "host": "100.64.0.1",
          "config": "node-a",
          "role": "web-server",
          "mode": "switch"
        }
      ]
    }
  }'
```

### Manual Backup
```bash
# Trigger backup workflow manually
curl -X POST \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/your-username/HomeLab/workflows/backup.yaml/dispatches \
  -d '{
    "ref": "main",
    "inputs": {
      "target_servers": "100.64.0.1,100.64.0.2",
      "backup_type": "full"
    }
  }'
```

### Terraform Integration
```bash
# From your Terraform CI/CD pipeline
curl -X POST \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/your-username/HomeLab/dispatches \
  -d '{
    "event_type": "terraform-changed",
    "client_payload": {
      "repo": "infrastructure/terraform",
      "resources": [
        {
          "type": "proxmox_vm_qemu",
          "attributes": {
            "public_ip": "100.64.0.1",
            "name": "web-server-1",
            "role": "web-server"
          }
        }
      ]
    }
  }'
```

## Customization Guide

### Adding New Roles

1. Create a new role file in `nixos/roles/`:
```nix
# nixos/roles/custom-role.nix
{ config, pkgs, ... }:

{
  imports = [
    ../modules/services/required-service.nix
  ];

  # Your custom configuration
  services.your-service.enable = true;
  
  # Additional settings
  networking.firewall.allowedTCPPorts = [ 8080 ];
}
```

2. Update `nixos/flake.nix` to include the new role:
```nix
roleLibrary = {
  # existing roles...
  custom-role = ./roles/custom-role.nix;
};
```

### Adding New Service Modules

1. Create a service module in `nixos/modules/`:
```nix
# nixos/modules/new-service.nix
{ config, pkgs, ... }:

{
  services.new-service = {
    enable = true;
    # Service configuration
  };
}
```

2. Reference in your role or host configuration

## Security Considerations

1. **SSH Key Management**: Ensure SSH private keys are stored securely in GitHub Secrets
2. **Network Security**: Tailscale provides secure networking between CI/CD and target servers
3. **Access Control**: Limit webhook triggers to authorized sources
4. **Backup Security**: Backup artifacts contain sensitive data and should be treated accordingly
5. **Secret Rotation**: Regularly rotate Tailscale and SSH keys

## Troubleshooting

### Common Issues

1. **Deployment Failures**
   - Check Tailscale connectivity
   - Verify SSH key permissions
   - Ensure target servers are accessible

2. **Configuration Errors**
   - Validate NixOS syntax with `nix flake check`
   - Check role definitions for missing imports
   - Verify webhook payload format

3. **Backup Issues**
   - Ensure sufficient disk space on target servers
   - Check SSH connectivity for backup operations
   - Verify file permissions for backup directories

### Debug Mode

Enable debug logging by setting:
```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

## Monitoring and Maintenance

### Monitoring Integration
- Prometheus metrics collection from backup servers
- Grafana dashboards for system health
- Log aggregation for workflow executions

### Maintenance Tasks
- Regular backup verification
- SSH key rotation
- Tailscale network cleanup
- GitHub artifact cleanup

## Tag-Based Deployment Strategy

The system supports tag-based deployment decisions:

1. **Infrastructure Tags**: Applied during Terraform deployment
2. **Service Tags**: Define which services should run on which hosts
3. **Environment Tags**: Separate staging, production, and development environments

Tags are used by the CI/CD pipeline to:
- Determine which configurations to apply
- Trigger appropriate deployment workflows
- Maintain inventory accuracy via the AWS Lambda function

## Support and Contributing

1. **Issues**: Report bugs and feature requests via GitHub Issues
2. **Contributions**: Submit pull requests for improvements
3. **Documentation**: Update this README for any major changes

## License

This automation system is designed for homelab use. Adapt and modify as needed for your specific requirements.