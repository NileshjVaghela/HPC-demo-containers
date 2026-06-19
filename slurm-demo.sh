#!/bin/bash
# Slurm Docker Cluster - Automation Script
# Starts the cluster, verifies health, and runs all sample jobs

set -e

REPO_DIR="$HOME/slurm-docker-cluster"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# --- SETUP ---
echo "============================================"
echo "  Slurm Docker Cluster - Automation Script"
echo "============================================"
echo ""

# Stop any running containers
echo "--- Stopping existing containers ---"
sudo docker ps -q | xargs -r sudo docker stop > /dev/null 2>&1 || true
log "All containers stopped"

# Clone if needed
if [ ! -d "$REPO_DIR" ]; then
    echo "--- Cloning repository ---"
    git clone https://github.com/giovtorres/slurm-docker-cluster "$REPO_DIR"
    log "Repository cloned"
fi

cd "$REPO_DIR"

# Create .env if missing
[ ! -f .env ] && cp .env.example .env && log "Created .env from example"

# --- START CLUSTER ---
echo ""
echo "--- Starting Slurm cluster ---"
sudo docker compose up -d 2>&1 | grep -E "(Created|Started|Healthy|is already running)" || true
log "Docker compose started"

# Wait for health
echo ""
echo "--- Waiting for cluster to be healthy ---"
for i in $(seq 1 60); do
    HEALTHY=$(sudo docker compose ps --format json 2>/dev/null | grep -c '"healthy"' || echo 0)
    if [ "$HEALTHY" -ge 6 ]; then
        log "All 6 containers healthy"
        break
    fi
    if [ "$i" -eq 60 ]; then
        fail "Timeout waiting for containers to be healthy"
    fi
    sleep 5
    echo -n "."
done

# Verify nodes
echo ""
echo "--- Verifying Slurm nodes ---"
SINFO=$(sudo docker exec slurmctld sinfo -N --noheader 2>/dev/null)
NODE_COUNT=$(echo "$SINFO" | grep -c "idle" || echo 0)
if [ "$NODE_COUNT" -ge 2 ]; then
    log "Cluster ready: $NODE_COUNT nodes idle"
    sudo docker exec slurmctld sinfo
else
    warn "Nodes not idle yet, attempting resume..."
    sudo docker exec slurmctld scontrol update nodename=c1 state=resume 2>/dev/null || true
    sudo docker exec slurmctld scontrol update nodename=c2 state=resume 2>/dev/null || true
    sleep 5
    sudo docker exec slurmctld sinfo
fi

# --- RUN SAMPLE JOBS ---
echo ""
echo "============================================"
echo "  Running Sample Jobs"
echo "============================================"

# Job 1: Simple echo
echo ""
echo "--- Job 1: Simple Echo ---"
JOB1=$(sudo docker exec slurmctld sbatch --parsable --wrap="echo Hello from \$(hostname)")
log "Submitted job $JOB1"

# Job 2: Pi calculation
echo ""
echo "--- Job 2: Pi 10000 Digits ---"
sudo docker exec slurmctld bash -c 'cat > /data/pi_calc.sh << "EOF"
#!/bin/bash
#SBATCH --job-name=pi-10000
#SBATCH --nodes=1
#SBATCH --output=pi-result-%j.txt

python3 -c "
from decimal import Decimal, getcontext
import time
digits = 10000
getcontext().prec = digits + 50
start = time.time()
def compute_pi(n):
    getcontext().prec = n + 50
    C = 426880 * Decimal(10005).sqrt()
    K, M, X, L, S = Decimal(0), Decimal(1), Decimal(1), Decimal(13591409), Decimal(13591409)
    for i in range(1, n):
        M = M * (K**3 - 16*K) / (i**3)
        K += 12; L += 545140134; X *= -262537412640768000
        S += Decimal(M * L) / X
        if abs(Decimal(M * L) / X) < Decimal(10)**(-(n+20)): break
    return C / S
pi = compute_pi(digits)
elapsed = time.time() - start
print(f\"Pi computed to {digits} digits in {elapsed:.3f}s\")
print(str(pi)[:52] + \"...\")
"
EOF'
JOB2=$(sudo docker exec slurmctld sbatch --parsable /data/pi_calc.sh)
log "Submitted job $JOB2"

# Job 3: Monte Carlo (parallel)
echo ""
echo "--- Job 3: Monte Carlo Pi (parallel, 2 nodes) ---"
sudo docker exec slurmctld bash -c 'cat > /data/monte_carlo.sh << "EOF"
#!/bin/bash
#SBATCH --job-name=monte-carlo
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --output=monte-carlo-%j.txt

srun python3 -c "
import random, os, socket
samples = 10_000_000
inside = sum(1 for _ in range(samples) if random.random()**2 + random.random()**2 <= 1)
pi_est = 4.0 * inside / samples
print(f\"Task {os.environ.get(\"SLURM_PROCID\")} on {socket.gethostname()}: pi={pi_est:.8f} ({samples:,} samples)\")
"
EOF'
JOB3=$(sudo docker exec slurmctld sbatch --parsable /data/monte_carlo.sh)
log "Submitted job $JOB3"

# Job 4: Matrix multiply (array)
echo ""
echo "--- Job 4: Matrix Multiply (array 1-5) ---"
sudo docker exec slurmctld bash -c 'cat > /data/matrix.sh << "EOF"
#!/bin/bash
#SBATCH --job-name=matrix
#SBATCH --array=1-5
#SBATCH --output=matrix-%A_%a.txt

python3 -c "
import time, os, random
task = int(os.environ[\"SLURM_ARRAY_TASK_ID\"])
n = task * 100
random.seed(42 + task)
A = [[random.random() for _ in range(n)] for _ in range(n)]
B = [[random.random() for _ in range(n)] for _ in range(n)]
start = time.time()
C = [[sum(A[i][k]*B[k][j] for k in range(n)) for j in range(n)] for i in range(n)]
print(f\"Task {task}: {n}x{n} matrix multiply in {time.time()-start:.3f}s\")
"
EOF'
JOB4=$(sudo docker exec slurmctld sbatch --parsable /data/matrix.sh)
log "Submitted job $JOB4"

# Job 5: Fibonacci dependency chain
echo ""
echo "--- Job 5: Fibonacci Pipeline (3 dependent jobs) ---"
sudo docker exec slurmctld bash -c 'cat > /data/fib_a.sh << "EOF"
#!/bin/bash
#SBATCH --job-name=fib-compute
#SBATCH --output=fib-a-%j.txt

python3 -c "
import sys, time
sys.set_int_max_str_digits(1000000)
start = time.time()
def fib(n):
    a, b = 0, 1
    for _ in range(n): a, b = b, a+b
    return a
with open(\"/data/fib_results.txt\", \"w\") as f:
    for n in [1000, 5000, 10000, 50000, 100000]:
        d = len(str(fib(n)))
        f.write(f\"{n},{d}\n\")
        print(f\"F({n}) = {d} digits\")
print(f\"Done in {time.time()-start:.3f}s\")
"
EOF'

sudo docker exec slurmctld bash -c 'cat > /data/fib_b.sh << "EOF"
#!/bin/bash
#SBATCH --job-name=fib-analyze
#SBATCH --output=fib-b-%j.txt

python3 -c "
import math
phi = (1+math.sqrt(5))/2
with open(\"/data/fib_results.txt\") as f:
    for line in f:
        n, d = line.strip().split(\",\")
        print(f\"F({n}): {d} digits, ratio={int(d)/int(n):.5f}\")
print(f\"Expected ratio (log10 phi): {math.log10(phi):.5f}\")
"
EOF'

sudo docker exec slurmctld bash -c 'cat > /data/fib_c.sh << "EOF"
#!/bin/bash
#SBATCH --job-name=fib-summary
#SBATCH --output=fib-c-%j.txt

echo "=== Fibonacci Pipeline Complete ==="
cat /data/fib_results.txt
echo "Chain of 3 dependent jobs executed successfully."
EOF'

FIBA=$(sudo docker exec slurmctld sbatch --parsable /data/fib_a.sh)
FIBB=$(sudo docker exec slurmctld sbatch --parsable --dependency=afterok:$FIBA /data/fib_b.sh)
FIBC=$(sudo docker exec slurmctld sbatch --parsable --dependency=afterok:$FIBB /data/fib_c.sh)
log "Submitted chain: $FIBA → $FIBB → $FIBC"

# Job 6: Heat Diffusion Simulation (long running)
echo ""
echo "--- Job 6: 2D Heat Diffusion Simulation (~8-9 min) ---"
sudo docker exec slurmctld bash -c 'cat > /data/heat_sim.sh << "SCRIPT"
#!/bin/bash
#SBATCH --job-name=heat-simulation
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --output=heat-sim-%j.txt

srun python3 -c "
import time, os, socket

task_id = int(os.environ.get(\"SLURM_PROCID\", 0))
host = socket.gethostname()

grid_size = 300
iterations = 5000
dx = 1.0 / grid_size
alpha = 0.01
dt = 0.2 * dx * dx / alpha

print(f\"Task {task_id} on {host}: {grid_size}x{grid_size} grid, {iterations} iterations\")

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
        print(f\"  Task {task_id} [{host}] iter {t+1}/{iterations}: center={center:.4f}C, elapsed={elapsed:.1f}s\")

elapsed = time.time() - start
center = grid[grid_size//2][grid_size//2]
avg = sum(grid[i][j] for i in range(grid_size) for j in range(grid_size)) / (grid_size*grid_size)
print(f\"Task {task_id} on {host} DONE: center={center:.4f}C, avg={avg:.4f}C, time={elapsed:.1f}s\")
"
SCRIPT'
JOB6=$(sudo docker exec slurmctld sbatch --parsable /data/heat_sim.sh)
log "Submitted job $JOB6 (will run ~8-9 minutes)"

# --- WAIT FOR COMPLETION ---
echo ""
echo "--- Waiting for all jobs to complete ---"
for i in $(seq 1 180); do
    PENDING=$(sudo docker exec slurmctld squeue --noheader 2>/dev/null | wc -l)
    if [ "$PENDING" -eq 0 ]; then
        log "All jobs completed!"
        break
    fi
    if [ "$i" -eq 180 ]; then
        warn "Some jobs still running after 15 minutes"
        sudo docker exec slurmctld squeue
        break
    fi
    if [ $((i % 12)) -eq 0 ]; then
        RUNNING=$(sudo docker exec slurmctld squeue --noheader -t R 2>/dev/null | wc -l)
        echo " (${RUNNING} running)"
    else
        echo -n "."
    fi
    sleep 5
done

# --- RESULTS ---
echo ""
echo "============================================"
echo "  Results Summary"
echo "============================================"
echo ""

echo "--- Job Accounting ---"
sudo docker exec slurmctld sacct --format=JobID%8,JobName%15,State%12,Elapsed%10,NodeList%10 \
    -j $JOB1,$JOB2,$JOB3,$JOB4,$FIBA,$FIBB,$FIBC,$JOB6 | head -40
echo ""

echo "--- Pi Calculation Output ---"
sudo docker exec slurmctld cat /data/pi-result-$JOB2.txt 2>/dev/null || echo "(check pi-result-*.txt)"
echo ""

echo "--- Monte Carlo Output ---"
sudo docker exec slurmctld cat /data/monte-carlo-$JOB3.txt 2>/dev/null || echo "(check monte-carlo-*.txt)"
echo ""

echo "--- Matrix Multiply (Task 5 - largest) ---"
sudo docker exec slurmctld cat /data/matrix-${JOB4}_5.txt 2>/dev/null || echo "(check matrix-*.txt)"
echo ""

echo "--- Fibonacci Pipeline Final ---"
sudo docker exec slurmctld cat /data/fib-c-$FIBC.txt 2>/dev/null || echo "(check fib-c-*.txt)"
echo ""

echo "--- Heat Diffusion Simulation ---"
sudo docker exec slurmctld grep -E "(COMPLETE|DONE)" /data/heat-sim-$JOB6.txt 2>/dev/null || echo "(check heat-sim-*.txt)"
echo ""

log "Automation complete! Cluster is still running."
echo ""
echo "Useful commands:"
echo "  sudo docker exec slurmctld sinfo          # cluster status"
echo "  sudo docker exec slurmctld sacct           # job history"
echo "  sudo docker compose -f $REPO_DIR/docker-compose.yml down  # stop cluster"
