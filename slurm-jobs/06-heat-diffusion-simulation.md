# Sample Job 6: 2D Heat Diffusion Simulation (Multi-Node, Long Running)

## Overview
Simulates heat diffusion on a 2D plate using the finite difference method. Runs 4 parallel tasks across 2 nodes, each processing a 300×300 grid for 5000 iterations. Takes ~8-9 minutes to complete.

**Physics:** A metal plate starts at 20°C with boundary conditions (top=100°C, bottom=0°C, sides=50°C). Heat gradually diffuses inward.

## Job Script

```bash
#!/bin/bash
#SBATCH --job-name=heat-simulation
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --output=heat-sim-%j.txt

echo "============================================"
echo "  2D Heat Diffusion Simulation (Parallel)"
echo "============================================"
echo "Started: $(date)"
echo "Nodes: $SLURM_NODELIST"
echo "Tasks: $SLURM_NTASKS"
echo ""

srun python3 -c "
import time
import os
import socket

task_id = int(os.environ.get('SLURM_PROCID', 0))
host = socket.gethostname()

grid_size = 300
iterations = 5000
dx = 1.0 / grid_size
alpha = 0.01
dt = 0.2 * dx * dx / alpha  # CFL stable

print(f'Task {task_id} on {host}: {grid_size}x{grid_size} grid, {iterations} iterations')
print(f'  dx={dx:.6f}, dt={dt:.8f}, alpha={alpha}')

# Initialize grid at 20°C
grid = [[20.0]*grid_size for _ in range(grid_size)]
new_grid = [[20.0]*grid_size for _ in range(grid_size)]

# Boundary conditions
for i in range(grid_size):
    grid[0][i] = 100.0          # top = hot
    grid[grid_size-1][i] = 0.0  # bottom = cold
    grid[i][0] = 50.0           # left = warm
    grid[i][grid_size-1] = 50.0 # right = warm

r = alpha * dt / (dx * dx)
start = time.time()

for t in range(iterations):
    for i in range(1, grid_size-1):
        for j in range(1, grid_size-1):
            new_grid[i][j] = grid[i][j] + r * (
                grid[i+1][j] + grid[i-1][j] + grid[i][j+1] + grid[i][j-1] - 4*grid[i][j]
            )

    for i in range(grid_size):
        new_grid[0][i] = 100.0
        new_grid[grid_size-1][i] = 0.0
        new_grid[i][0] = 50.0
        new_grid[i][grid_size-1] = 50.0

    grid, new_grid = new_grid, grid

    if (t+1) % 1000 == 0:
        center = grid[grid_size//2][grid_size//2]
        elapsed = time.time() - start
        print(f'  Task {task_id} [{host}] iter {t+1}/{iterations}: center_temp={center:.4f} C, elapsed={elapsed:.1f}s')

elapsed = time.time() - start
center = grid[grid_size//2][grid_size//2]
avg = sum(grid[i][j] for i in range(grid_size) for j in range(grid_size)) / (grid_size*grid_size)

print(f'')
print(f'Task {task_id} on {host} COMPLETE:')
print(f'  Final center temperature: {center:.4f} C')
print(f'  Average temperature: {avg:.4f} C')
print(f'  Total time: {elapsed:.1f}s')
print(f'  Grid points processed: {grid_size*grid_size*iterations:,}')
"

echo ""
echo "All tasks finished: $(date)"
```

## How to Run

```bash
# Copy the job script into the controller
sudo docker exec slurmctld bash -c 'cat > /data/complex_simulation.sh << "SCRIPT"
#!/bin/bash
#SBATCH --job-name=heat-simulation
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --output=heat-sim-%j.txt

echo "============================================"
echo "  2D Heat Diffusion Simulation (Parallel)"
echo "============================================"
echo "Started: $(date)"
echo "Nodes: $SLURM_NODELIST"
echo "Tasks: $SLURM_NTASKS"
echo ""

srun python3 -c "
import time
import os
import socket

task_id = int(os.environ.get(\"SLURM_PROCID\", 0))
host = socket.gethostname()

grid_size = 300
iterations = 5000
dx = 1.0 / grid_size
alpha = 0.01
dt = 0.2 * dx * dx / alpha

print(f\"Task {task_id} on {host}: {grid_size}x{grid_size} grid, {iterations} iterations\")
print(f\"  dx={dx:.6f}, dt={dt:.8f}, alpha={alpha}\")

grid = [[20.0]*grid_size for _ in range(grid_size)]
new_grid = [[20.0]*grid_size for _ in range(grid_size)]

for i in range(grid_size):
    grid[0][i] = 100.0
    grid[grid_size-1][i] = 0.0
    grid[i][0] = 50.0
    grid[i][grid_size-1] = 50.0

r = alpha * dt / (dx * dx)
start = time.time()

for t in range(iterations):
    for i in range(1, grid_size-1):
        for j in range(1, grid_size-1):
            new_grid[i][j] = grid[i][j] + r * (
                grid[i+1][j] + grid[i-1][j] + grid[i][j+1] + grid[i][j-1] - 4*grid[i][j]
            )

    for i in range(grid_size):
        new_grid[0][i] = 100.0
        new_grid[grid_size-1][i] = 0.0
        new_grid[i][0] = 50.0
        new_grid[i][grid_size-1] = 50.0

    grid, new_grid = new_grid, grid

    if (t+1) % 1000 == 0:
        center = grid[grid_size//2][grid_size//2]
        elapsed = time.time() - start
        print(f\"  Task {task_id} [{host}] iter {t+1}/{iterations}: center_temp={center:.4f} C, elapsed={elapsed:.1f}s\")

elapsed = time.time() - start
center = grid[grid_size//2][grid_size//2]
avg = sum(grid[i][j] for i in range(grid_size) for j in range(grid_size)) / (grid_size*grid_size)

print(f\"\")
print(f\"Task {task_id} on {host} COMPLETE:\")
print(f\"  Final center temperature: {center:.4f} C\")
print(f\"  Average temperature: {avg:.4f} C\")
print(f\"  Total time: {elapsed:.1f}s\")
print(f\"  Grid points processed: {grid_size*grid_size*iterations:,}\")
"

echo ""
echo "All tasks finished: $(date)"
SCRIPT'

# Submit the job
sudo docker exec slurmctld sbatch /data/complex_simulation.sh

# Monitor progress (job runs ~8-9 minutes)
sudo docker exec slurmctld squeue
watch -n 10 'sudo docker exec slurmctld squeue'

# View output when done
sudo docker exec slurmctld cat /data/heat-sim-<jobid>.txt
```

## Expected Output

```
============================================
  2D Heat Diffusion Simulation (Parallel)
============================================
Started: Sun May 10 01:58:42 UTC 2026
Nodes: c[1-2]
Tasks: 4

Task 0 on c1: 300x300 grid, 5000 iterations
  dx=0.003333, dt=0.00022222, alpha=0.01
  Task 0 [c1] iter 1000/5000: center_temp=20.0000 C, elapsed=96.6s
  Task 0 [c1] iter 2000/5000: center_temp=20.0000 C, elapsed=197.2s
  Task 0 [c1] iter 3000/5000: center_temp=20.0018 C, elapsed=295.7s
  Task 0 [c1] iter 4000/5000: center_temp=20.0214 C, elapsed=399.1s
  Task 0 [c1] iter 5000/5000: center_temp=20.0961 C, elapsed=502.0s

Task 0 on c1 COMPLETE:
  Final center temperature: 20.0961 C
  Average temperature: 32.7290 C
  Total time: 502.0s
  Grid points processed: 450,000,000

(similar output for Tasks 1, 2, 3 on c1 and c2)

All tasks finished: Sun May 10 02:07:21 UTC 2026
```

## What This Demonstrates
- Long-running multi-node parallel computation (~8-9 minutes)
- Numerically stable finite difference simulation (CFL condition satisfied)
- Progress reporting during execution
- Real scientific computing workload pattern
- `srun` distributing tasks across nodes
- Slurm handling long jobs with proper scheduling

## Tuning Runtime

Adjust these parameters to change how long the job runs:

| Parameter | Effect |
|-----------|--------|
| `grid_size=300` | Larger = longer (quadratic) |
| `iterations=5000` | More = longer (linear) |
| `--ntasks=4` | More tasks = more parallel work |

Approximate runtimes:
- `grid_size=200, iterations=3000` → ~2-3 minutes
- `grid_size=300, iterations=5000` → ~8-9 minutes
- `grid_size=400, iterations=5000` → ~15-20 minutes
