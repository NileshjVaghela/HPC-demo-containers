# HPC with Slurm - Docker Demo (Updated Howto)

## What We're Building

A tiny HPC cluster with:
- 1 controller node (slurmctld)
- 2 CPU worker nodes (c1, c2)
- MariaDB + Slurm Database Daemon (slurmdbd) for job accounting
- Slurm REST API (slurmrestd)
- Shared storage via Docker volumes
- Munge authentication + JWT alternative

All running in Docker Compose. No cloud account or extra hardware needed.

---

## Prerequisites

- Docker + Docker Compose v2 (the `docker compose` command)
- Git
- A terminal
- ~15-20 minutes (first run includes image build)
- sudo access (or Docker configured for non-root)

---

## Step 1 - Clone the Repository

```bash
git clone https://github.com/giovtorres/slurm-docker-cluster
cd slurm-docker-cluster
```

---

## Step 2 - Configure Environment

```bash
cp .env.example .env
```

Default settings give you:
- Slurm 25.11.4
- 2 CPU worker nodes
- No GPU workers
- SSH disabled

Edit `.env` if you want to change anything (usually not needed for the demo).

---

## Step 3 - Start the Cluster

```bash
sudo docker compose up -d
```

First run builds the image from source (~5-10 minutes). Subsequent starts are fast.

Verify all containers are healthy:

```bash
sudo docker compose ps
```

Expected output — 6 containers all showing `(healthy)`:
- `mysql` — MariaDB for job accounting
- `slurmdbd` — Slurm database daemon
- `slurmctld` — Slurm controller
- `slurmrestd` — Slurm REST API
- `slurm-cpu-worker-1` — Compute node c1
- `slurm-cpu-worker-2` — Compute node c2

---

## Step 4 - Verify Cluster Status

```bash
sudo docker exec slurmctld sinfo
```

Expected:
```
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
cpu*         up   infinite      2   idle c[1-2]
gpu          up   infinite      0    n/a
```

Both nodes `idle` = ready for work. The `gpu` partition is empty (no GPU workers started).

For node-level detail:
```bash
sudo docker exec slurmctld sinfo -N
```

---

## Step 5 - Submit Your First Job

```bash
sudo docker exec slurmctld sbatch --wrap="echo Hello from \$(hostname)"
```

Output: `Submitted batch job 1`

Check the result (wait a few seconds):
```bash
sudo docker exec slurmctld cat /data/slurm-1.out
```

Expected: `Hello from c1`

---

## Step 6 - Multi-Node Job Script

Create a job script inside the controller:

```bash
sudo docker exec slurmctld bash -c 'cat > /data/job.sh << "EOF"
#!/bin/bash
#SBATCH --job-name=my-first-job
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --output=output-%j.txt

echo "Job started on: $(date)"
echo "Running on nodes: $SLURM_NODELIST"
srun hostname
echo "Job done."
EOF'
```

Submit it:
```bash
sudo docker exec slurmctld sbatch /data/job.sh
```

Check output (replace `2` with actual job ID):
```bash
sudo docker exec slurmctld cat /data/output-2.txt
```

Expected:
```
Job started on: Sun May 10 01:20:32 UTC 2026
Running on nodes: c[1-2]
c1
c2
c1
c2
Job done.
```

Both nodes ran work — that's multi-node execution.

---

## Step 7 - Array Job

Submit 5 tasks at once:
```bash
sudo docker exec slurmctld sbatch --array=1-5 --wrap="echo I am task number \$SLURM_ARRAY_TASK_ID"
```

Check outputs:
```bash
sudo docker exec slurmctld bash -c 'cat /data/slurm-3_*.out'
```

Expected:
```
I am task number 1
I am task number 2
I am task number 3
I am task number 4
I am task number 5
```

---

## Step 8 - Submit and Cancel a Job

Submit a long-running job:
```bash
sudo docker exec slurmctld sbatch --wrap="sleep 120"
```

See it running:
```bash
sudo docker exec slurmctld squeue
```

Cancel it (replace `<jobid>` with actual ID):
```bash
sudo docker exec slurmctld scancel <jobid>
```

Verify it's gone:
```bash
sudo docker exec slurmctld squeue
```

---

## Step 9 - Useful Commands Reference

Run these from inside the controller (`sudo docker exec slurmctld <command>`):

| Command | Purpose |
|---------|---------|
| `sinfo` | Node status and partitions |
| `sinfo -N` | Node-level detail |
| `squeue` | All jobs in queue |
| `squeue -u root` | Jobs for a specific user |
| `scontrol show job <jobid>` | Full details of a job |
| `scancel <jobid>` | Kill a job |
| `sacct` | Job accounting/history |
| `sacct --format=JobID,JobName,State,ExitCode,Elapsed` | Formatted job history |

---

## Step 10 - View Slurm Configuration

```bash
sudo docker exec slurmctld cat /etc/slurm/slurm.conf
```

Key things to note:
- `ClusterName=linux`
- `SlurmctldHost=slurmctld`
- Nodes register dynamically (no static NodeName lines)
- `NodeSet=cpu_nodes Feature=cpu` groups CPU workers
- `PartitionName=cpu` is the default partition
- Authentication: Munge primary, JWT alternative
- Accounting via slurmdbd → MariaDB

---

## Architecture

```
┌──────────────────────────────────────────────────┐
│              Docker Compose Network               │
│                                                  │
│  ┌─────────┐    ┌──────────┐    ┌─────────────┐ │
│  │  mysql   │───→│ slurmdbd │───→│  slurmctld  │ │
│  │(MariaDB) │    │(DB Daemon)│    │(Controller) │ │
│  └─────────┘    └──────────┘    └──────┬──────┘ │
│                                        │        │
│                              ┌─────────┼────┐   │
│                              ↓              ↓   │
│                        ┌──────────┐  ┌──────────┐│
│                        │    c1    │  │    c2    ││
│                        │ (worker) │  │ (worker) ││
│                        └──────────┘  └──────────┘│
│                                                  │
│  ┌────────────┐                                  │
│  │ slurmrestd │  (REST API on port 6820)         │
│  └────────────┘                                  │
└──────────────────────────────────────────────────┘

Shared Volumes:
  - etc_munge    → /etc/munge (auth keys)
  - etc_slurm    → /etc/slurm (config)
  - slurm_jobdir → /data (job working directory)
  - var_log_slurm → /var/log/slurm (logs)
```

---

## Demo Flow (10-15 minutes)

1. `sinfo` — "Here's our cluster, two nodes ready"
2. Submit simple echo job — "Job submitted, here's the ID"
3. `squeue` — "Here it is in the queue"
4. Show output file — "It ran on c1"
5. Submit multi-node `job.sh` — "Now using both nodes"
6. Show output — "Both c1 and c2 ran work"
7. Submit array job (1-5) — "Five tasks at once"
8. Submit sleep job and cancel it — "We can kill jobs too"
9. Show `slurm.conf` briefly — "This is how the cluster is defined"
10. Show `sacct` — "Full job history with accounting"

---

## Troubleshooting

### Nodes stuck in "drain" state
```bash
sudo docker exec slurmctld scontrol update nodename=c1 state=resume
sudo docker exec slurmctld scontrol update nodename=c2 state=resume
```

### Jobs stuck in "PD" (pending) forever
```bash
sudo docker exec slurmctld scontrol show job <jobid>
# Look at the "Reason" field
```

### Container won't start
```bash
sudo docker compose logs slurmctld
sudo docker compose logs slurmdbd
```

### Nodes not registering (sinfo shows 0 nodes)
Wait 30 seconds — nodes register dynamically after slurmctld is healthy. If still missing:
```bash
sudo docker compose restart cpu-worker
```

### "Munge authentication" errors
Munge key is shared via the `etc_munge` volume. If corrupted:
```bash
sudo docker compose down -v
sudo docker compose up -d
```

---

## Going Further

Once comfortable with the basics:

- **Resource limits:** `--mem=512M` or `--cpus-per-task=2`
- **Job dependencies:** `sbatch --dependency=afterok:<jobid>`
- **REST API:** `curl http://localhost:6820/slurm/v0.0.41/jobs` (requires JWT token)
- **Scaling workers:** Edit `CPU_WORKER_COUNT=4` in `.env` and `docker compose up -d`
- **Monitoring:** `docker compose --profile monitoring up -d` (adds Elasticsearch + Kibana)
- **Open OnDemand:** `docker compose --profile ondemand up -d` (web portal on port 8080)

---

## Cleanup

```bash
cd /home/nilesh/slurm-docker-cluster

# Stop containers
sudo docker compose down

# Stop and remove all data (fresh start next time)
sudo docker compose down -v
```

---

## Key Differences from Original Howto

| Original Howto Says | Actual Behavior |
|---------------------|-----------------|
| Named containers `c1`, `c2` | Containers are `slurm-cpu-worker-1`, `slurm-cpu-worker-2` (but register as c1, c2 in Slurm) |
| 3 containers total | 6 containers (adds mysql, slurmdbd, slurmrestd) |
| `docker-compose` (v1) | Use `docker compose` (v2) |
| `docker exec -it slurmctld bash` then run commands | Can also run directly: `sudo docker exec slurmctld <command>` |
| `systemctl status munge` | Won't work (no systemd in containers). Munge starts via entrypoint. |
| Static node definitions in slurm.conf | Nodes register dynamically |
| Working directory is `/` | Working directory is `/data` (job outputs go here) |
