# Sample Job 4: Matrix Multiplication (Array Job)

## Overview
Performs matrix multiplication with different matrix sizes using a Slurm array job. Each array task computes a different size, demonstrating how array jobs handle parameter sweeps.

## Job Script

```bash
#!/bin/bash
#SBATCH --job-name=matrix-multiply
#SBATCH --array=1-5
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=matrix-%A_%a.txt

echo "=== Matrix Multiplication - Task $SLURM_ARRAY_TASK_ID ==="
echo "Started: $(date)"
echo "Running on: $(hostname)"
echo ""

python3 -c "
import time
import os
import random

task_id = int(os.environ['SLURM_ARRAY_TASK_ID'])

# Each task uses a different matrix size
sizes = {1: 100, 2: 200, 3: 300, 4: 400, 5: 500}
n = sizes[task_id]

print(f'Matrix size: {n}x{n}')
print(f'Total multiplications: {n**3:,}')
print()

# Generate random matrices
random.seed(42 + task_id)
A = [[random.random() for _ in range(n)] for _ in range(n)]
B = [[random.random() for _ in range(n)] for _ in range(n)]

# Multiply
start = time.time()
C = [[sum(A[i][k] * B[k][j] for k in range(n)) for j in range(n)] for i in range(n)]
elapsed = time.time() - start

print(f'Computation time: {elapsed:.3f} seconds')
print(f'Result C[0][0] = {C[0][0]:.6f}')
print(f'Result C[n-1][n-1] = {C[n-1][n-1]:.6f}')
"

echo ""
echo "Finished: $(date)"
```

## How to Run

```bash
# Copy the job script into the controller
sudo docker exec slurmctld bash -c 'cat > /data/matrix_multiply.sh << "SCRIPT"
#!/bin/bash
#SBATCH --job-name=matrix-multiply
#SBATCH --array=1-5
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=matrix-%A_%a.txt

echo "=== Matrix Multiplication - Task $SLURM_ARRAY_TASK_ID ==="
echo "Started: $(date)"
echo "Running on: $(hostname)"
echo ""

python3 -c "
import time
import os
import random

task_id = int(os.environ[\"SLURM_ARRAY_TASK_ID\"])

sizes = {1: 100, 2: 200, 3: 300, 4: 400, 5: 500}
n = sizes[task_id]

print(f\"Matrix size: {n}x{n}\")
print(f\"Total multiplications: {n**3:,}\")
print()

random.seed(42 + task_id)
A = [[random.random() for _ in range(n)] for _ in range(n)]
B = [[random.random() for _ in range(n)] for _ in range(n)]

start = time.time()
C = [[sum(A[i][k] * B[k][j] for k in range(n)) for j in range(n)] for i in range(n)]
elapsed = time.time() - start

print(f\"Computation time: {elapsed:.3f} seconds\")
print(f\"Result C[0][0] = {C[0][0]:.6f}\")
print(f\"Result C[n-1][n-1] = {C[n-1][n-1]:.6f}\")
"

echo ""
echo "Finished: $(date)"
SCRIPT'

# Submit the array job
sudo docker exec slurmctld sbatch /data/matrix_multiply.sh

# Monitor all array tasks
sudo docker exec slurmctld squeue

# View all outputs (replace <jobid> with the base job ID)
sudo docker exec slurmctld bash -c 'cat /data/matrix-<jobid>_*.txt'
```

## Expected Output (one task)

```
=== Matrix Multiplication - Task 3 ===
Started: Sun May 10 01:35:00 UTC 2026
Running on: c2

Matrix size: 300x300
Total multiplications: 27,000,000

Computation time: 4.521 seconds
Result C[0][0] = 75.234891
Result C[n-1][n-1] = 74.891023

Finished: Sun May 10 01:35:05 UTC 2026
```

## What This Demonstrates
- Slurm array jobs (`--array=1-5`)
- Parameter sweep pattern (different sizes per task)
- Output file naming with `%A` (array job ID) and `%a` (task ID)
- Tasks distributed across available nodes automatically
- Increasing computational complexity across tasks
