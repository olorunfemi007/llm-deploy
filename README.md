# llm-deploy

Terraform-managed Kubernetes cluster on Google Cloud — 3 e2-small VMs (1 control-plane + 2 workers) with kubeadm.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- GCP project with **Compute Engine API** enabled
- GCP service account with `Compute Admin` and `Storage Admin` roles
- GCS bucket for Terraform state
- SSH key pair (`~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`)

## Local Setup

```bash
cd terraform

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize with remote state
terraform init \
  -backend-config="bucket=YOUR_BUCKET_NAME" \
  -backend-config="prefix=terraform/state"

# Preview changes
terraform plan

# Deploy
terraform apply
```

## GitHub Actions CI/CD

Add these secrets to your GitHub repository:

| Secret | Description |
|--------|-------------|
| `GCP_SA_KEY` | Service account JSON key |
| `GCP_PROJECT_ID` | Your GCP project ID |
| `TF_STATE_BUCKET` | GCS bucket name for Terraform state |

The workflow runs:
- **On PRs**: `terraform plan` — posts the plan as a PR comment
- **On push to main**: `terraform apply` — deploys the infrastructure

## Post-Deploy: Joining Workers to the Cluster

After `terraform apply` completes:

1. **SSH into the control-plane node:**
   ```bash
   ssh ubuntu@<control-plane-external-ip>
   ```

2. **Wait for the startup script to finish:**
   ```bash
   sudo cloud-init status --wait
   ```

3. **Get the join command:**
   ```bash
   sudo cat /root/kubeadm-join-command.sh
   ```

4. **SSH into each worker and run the join command as root:**
   ```bash
   ssh ubuntu@<worker-external-ip>
   sudo <paste-join-command-here>
   ```

5. **Verify the cluster (back on control-plane):**
   ```bash
   kubectl get nodes
   ```

   All 3 nodes should show `Ready` status.

## Architecture

```
┌─────────────────────────────────────────┐
│              k8s-vpc (10.0.0.0/24)      │
│                                         │
│  ┌──────────────┐  ┌──────────────────┐ │
│  │ control-plane│  │ worker-1         │ │
│  │ 10.0.0.10    │  │ (DHCP)           │ │
│  │ e2-small     │  │ e2-small         │ │
│  │ kubeadm init │  │ kubeadm join     │ │
│  └──────────────┘  └──────────────────┘ │
│                    ┌──────────────────┐  │
│                    │ worker-2         │  │
│                    │ (DHCP)           │  │
│                    │ e2-small         │  │
│                    │ kubeadm join     │  │
│                    └──────────────────┘  │
└─────────────────────────────────────────┘

CNI: Flannel (10.244.0.0/16)
```

## Cleanup

```bash
terraform destroy
```
