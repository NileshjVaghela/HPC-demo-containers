# Sample Job 2: Monte Carlo Pi Estimation (Parallel)

## Overview
Estimates Pi using the Monte Carlo method across multiple nodes and tasks. Each task generates random points and checks if they fall inside a unit circle. Classic HPC parallel workload.

## Job Script

```bash
#!/bin/bash
#SBATCH --job-name=monte-carlo-pi
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --output=monte-carlo-%j.txt

echo "=== Monte Carlo Pi Estimation (Parallel) ==="
echo "Started: $(date)"
echo "Nodes: $SLURM_NODELIST"
echo "Tasks: $SLURM_NTASKS"
echo ""

srun python3 -c "
import random
import os
import socket

samples = 10_000_000
inside = 0

for _ in range(samples):
    x = random.random()
    y = random.random()
    if x*x + y*y <= 1.0:
        inside += 1

pi_estimate = 4.0 * inside / samples
host = socket.gethostname()
task_id = os.environ.get('SLURM_PROCID', '?')
print(f'Task {task_id} on {host}: pi ≈ {pi_estimate:.10f} ({samples:,} samples)')
"

echo ""
echo "Finished: $(date)"
```

## How to Run

```bash
# Copy the job script into the controller
sudo docker exec slurmctld bash -c 'cat > /data/monte_carlo_pi.sh << "SCRIPT"
#!/bin/bash
#SBATCH --job-name=monte-carlo-pi
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --output=monte-carlo-%j.txt

echo "=== Monte Carlo Pi Estimation (Parallel) ==="
echo "Started: $(date)"
echo "Nodes: $SLURM_NODELIST"
echo "Tasks: $SLURM_NTASKS"
echo ""

srun python3 -c "
import random
import os
import socket

samples = 10_000_000
inside = 0

for _ in range(samples):
    x = random.random()
    y = random.random()
    if x*x + y*y <= 1.0:
        inside += 1

pi_estimate = 4.0 * inside / samples
host = socket.gethostname()
task_id = os.environ.get(\"SLURM_PROCID\", \"?\")
print(f\"Task {task_id} on {host}: pi ≈ {pi_estimate:.10f} ({samples:,} samples)\")
"

echo ""
echo "Finished: $(date)"
SCRIPT'

# Submit the job
sudo docker exec slurmctld sbatch /data/monte_carlo_pi.sh

# Monitor (refreshes every 2 seconds)
sudo docker exec slurmctld squeue

# View output
sudo docker exec slurmctld cat /data/monte-carlo-<jobid>.txt
```

## Expected Output

```
=== Monte Carlo Pi Estimation (Parallel) ===
Started: Sun May 10 01:29:42 UTC 2026
Nodes: c[1-2]
Tasks: 4

Task 0 on c1: pi ≈ 3.1420832000 (10,000,000 samples)
Task 1 on c1: pi ≈ 3.1414216000 (10,000,000 samples)
Task 2 on c2: pi ≈ 3.1416384000 (10,000,000 samples)
Task 3 on c2: pi ≈ 3.1421344000 (10,000,000 samples)

Finished: Sun May 10 01:29:55 UTC 2026
```

## What This Demonstrates
- Multi-node parallel execution with `srun`
- 4 tasks distributed across 2 nodes (2 per node)
- Each task runs independently with its own random seed
- Slurm environment variables (`SLURM_PROCID`, `SLURM_NODELIST`)
- Real-world embarrassingly parallel workload pattern
