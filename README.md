# llm-deploy

Distributed LLM inference across cheap CPU VMs on GCP — serving **Qwen2.5-Coder-3B-Instruct** via [llama.cpp](https://github.com/ggml-org/llama.cpp) RPC pipeline parallelism on a kubeadm Kubernetes cluster of e2-small instances (~$7/month).

Live at: **pythiaintel.com** (2 concurrent users)

> **Read the full write-up:** [Distributed LLM Inference Across Cheap CPU VMs, and Why GPUs Still Reigns](https://www.linkedin.com/pulse/distributed-llm-inference-across-cheap-cpu-vms-why-gpus-femi-kawonise-ou4zc/)

---

## Why

A 3B-parameter model in Q4_K_M quantization is ~2 GB on disk — too large to fit in the 2 GB RAM of a single e2-small VM. The solution: split the model across pods using llama.cpp's RPC backend so each node only holds a shard. One `llama-server` pod orchestrates three `rpc-server` worker pods, each on a different node, forming a CPU-only inference pipeline.

This is a learning project that proves distributed CPU inference *works*, while honestly documenting where it falls short compared to GPU hardware.

---

## Architecture

### Kubernetes Cluster (Terraform-provisioned)

```
┌────────────────────────────────────────────────────────────────────────┐
│                         k8s-vpc (10.0.0.0/24)                          │
│                                                                        │
│  ┌───────────────┐  ┌────────────────────┐  ┌──────────────────────┐  │
│  │ control-plane │  │  k8s-worker-<id>   │  │   k8s-worker-<id>    │  │
│  │  10.0.0.10    │  │   (DHCP)           │  │   (DHCP)             │  │
│  │  e2-small     │  │   e2-small         │  │   e2-small           │  │
│  │  kubeadm init │  │   kubeadm join     │  │   kubeadm join       │  │
│  └───────────────┘  │   [llama-server]   │  │   [rpc-worker-0]     │  │
│                     └────────────────────┘  └──────────────────────┘  │
│                     ┌────────────────────┐  ┌──────────────────────┐  │
│                     │  k8s-worker-<id>   │  │   k8s-worker-<id>    │  │
│                     │   (DHCP)           │  │   (DHCP)             │  │
│                     │   e2-small         │  │   e2-small           │  │
│                     │   kubeadm join     │  │   kubeadm join       │  │
│                     │   [rpc-worker-1]   │  │   [rpc-worker-2]     │  │
│                     └────────────────────┘  └──────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
Workers provisioned by Instance Group Manager (locked at 4 replicas)
CNI: Flannel (10.244.0.0/16)
```

### LLM Serving Topology (Kubernetes workloads)

```
                   ┌──────────────┐
   HTTP :8080      │  llama-server│  (Deployment, 1 replica)
  ──────────────▶  │  pod         │  Downloads model on init,
                   │  worker-0    │  serves OpenAI-compatible API
                   └──────┬───────┘
                          │ llama.cpp RPC (port 50052)
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
   │ rpc-worker-0│ │ rpc-worker-1│ │ rpc-worker-2│
   │  (node 0)   │ │  (node 1)   │ │  (node 2)   │
   └─────────────┘ └─────────────┘ └─────────────┘
         StatefulSet — one pod per node (podAntiAffinity)
         Headless Service: llama-rpc.llm-inference.svc.cluster.local
```

Ingress (nginx) → `llama-server:8080` → RPC workers → pipeline parallel inference.

---

## Model

| Property | Value |
|---|---|
| Model | Qwen2.5-Coder-3B-Instruct |
| Format | GGUF (Q4_K_M quantization) |
| Disk size | ~2 GB |
| Source | Hugging Face (downloaded at pod startup) |
| Context | 2,048 tokens |
| Parallel slots | 2 |
| Batch size | 256 |

---

## Performance

Measured on 4 CPU pods across e2-small instances (2 vCPU, 2 GB RAM each):

| Metric | Value |
|---|---|
| Throughput | ~4.8 tokens/sec |
| Time to first token (TTFT) | ~65.9 ms |
| Per-token generation | ~207–209 ms |
| 10-token request | ~3.1 s |
| 100-token request | ~22.1 s |
| Single user latency | ~12.1 s |
| Two concurrent users | ~17.8 s each (+47%) |

**vs. vLLM on A100:** 100+ tokens/sec with the same model class — a ~21× gap.

### Bottlenecks

1. **CPU arithmetic** — matrix multiplication on e2-small vCPUs is the primary floor
2. **Network latency** — ~0.79 ms per hop × 4 hops = ~3.16 ms overhead per token (~1.5% of total)
3. **Static KV cache** — allocated upfront, limits concurrency to 2 slots
4. **Pipeline rigidity** — worker failure requires a full pipeline restart

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- GCP project with **Compute Engine API** and **Artifact Registry API** enabled
- GCP service account with `Compute Admin`, `Storage Admin`, and `Artifact Registry Writer` roles
- GCS bucket for Terraform state
- SSH key pair (`~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`)

---

## Local Setup

```bash
cd terraform

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GCP project, region, bucket, etc.

terraform init \
  -backend-config="bucket=YOUR_BUCKET_NAME" \
  -backend-config="prefix=terraform/state"

terraform plan
terraform apply
```

---

## GitHub Actions CI/CD

Add these secrets to your GitHub repository:

| Secret | Description |
|---|---|
| `GCP_PROJECT_ID` | Your GCP project ID |
| `TF_STATE_BUCKET` | GCS bucket name for Terraform state |

The workflow runs three jobs:

| Trigger | Job | Action |
|---|---|---|
| Pull request | `terraform-plan` | Runs `terraform plan`, posts result as PR comment |
| Push to `main` | `terraform-apply` | Runs `terraform apply` — provisions infrastructure |
| Push to `main` | `build-push-rpc` | Builds `Dockerfile.rpc`, pushes image to GCP Artifact Registry |

---

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
   # All 5 nodes should show Ready (1 control-plane + 4 workers)
   ```

---

## Deploying the LLM Stack

Once the cluster is up, apply the manifests from the control-plane (or any machine with `kubectl` configured):

```bash
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/serviceaccount.yaml
kubectl apply -f manifests/nfs-pv.yaml
kubectl apply -f manifests/nfs-pvc.yaml
kubectl apply -f manifests/configmap.yaml
kubectl apply -f manifests/rpc-worker.yaml
kubectl apply -f manifests/deployment.yaml
kubectl apply -f manifests/service.yaml
kubectl apply -f manifests/ingress.yaml
```

The `llama-server` pod has two init containers that run in order:
1. **wait-for-rpc** — polls each RPC worker until all three are reachable
2. **model-downloader** — downloads the GGUF model from Hugging Face into the shared PVC (skipped if already present)

Once the server pod is `Ready`, the API is available at `http://<ingress-ip>/`:

```bash
curl http://<ingress-ip>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder",
    "messages": [{"role": "user", "content": "Write a Python hello world"}]
  }'
```

---

## Cleanup

```bash
# Remove Kubernetes workloads
kubectl delete -f manifests/

# Destroy GCP infrastructure
cd terraform && terraform destroy
```

---

## Read More

Full technical write-up with benchmarks, bottleneck analysis, and a comparison against GPU inference:

**[Distributed LLM Inference Across Cheap CPU VMs, and Why GPUs Still Reigns (k8s, GCP)](https://www.linkedin.com/pulse/distributed-llm-inference-across-cheap-cpu-vms-why-gpus-femi-kawonise-ou4zc/)**
