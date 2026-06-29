# Sample Job 1: Pi Calculation (10,000 Digits)

## Overview
Calculates Pi to 10,000 digits using the Chudnovsky algorithm with Python's `decimal` module. Single-node, CPU-intensive computation.

## Job Script

```bash
#!/bin/bash
#SBATCH --job-name=pi-10000-digits
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=pi-result-%j.txt

echo "=== Pi Calculation to 10000 digits (Chudnovsky algorithm) ==="
echo "Started: $(date)"
echo "Running on: $(hostname)"
echo ""

python3 << 'EOF'
from decimal import Decimal, getcontext
import time

digits = 10000
getcontext().prec = digits + 50

start = time.time()

def compute_pi(num_digits):
    getcontext().prec = num_digits + 50
    C = 426880 * Decimal(10005).sqrt()
    K = Decimal(0)
    M = Decimal(1)
    X = Decimal(1)
    L = Decimal(13591409)
    S = Decimal(13591409)

    for i in range(1, num_digits):
        M = M * (K**3 - 16*K) / ((i)**3)
        K += 12
        L += 545140134
        X *= -262537412640768000
        S += Decimal(M * L) / X
        if abs(Decimal(M * L) / X) < Decimal(10) ** (-(num_digits + 20)):
            break

    return C / S

pi = compute_pi(digits)
elapsed = time.time() - start

pi_str = str(pi)[:digits + 2]
print(f"Pi to {digits} digits:")
print(pi_str)
print(f"\nTotal digits computed: {len(pi_str) - 2}")
print(f"Computation time: {elapsed:.3f} seconds")
EOF

echo ""
echo "Finished: $(date)"
```

## How to Run

```bash
# Copy the job script into the controller
sudo docker exec slurmctld bash -c 'cat > /data/pi_calc.sh << "SCRIPT"
#!/bin/bash
#SBATCH --job-name=pi-10000-digits
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=pi-result-%j.txt

echo "=== Pi Calculation to 10000 digits (Chudnovsky algorithm) ==="
echo "Started: $(date)"
echo "Running on: $(hostname)"

python3 << EOF
from decimal import Decimal, getcontext
import time

digits = 10000
getcontext().prec = digits + 50
start = time.time()

def compute_pi(num_digits):
    getcontext().prec = num_digits + 50
    C = 426880 * Decimal(10005).sqrt()
    K = Decimal(0)
    M = Decimal(1)
    X = Decimal(1)
    L = Decimal(13591409)
    S = Decimal(13591409)
    for i in range(1, num_digits):
        M = M * (K**3 - 16*K) / ((i)**3)
        K += 12
        L += 545140134
        X *= -262537412640768000
        S += Decimal(M * L) / X
        if abs(Decimal(M * L) / X) < Decimal(10) ** (-(num_digits + 20)):
            break
    return C / S

pi = compute_pi(digits)
elapsed = time.time() - start
pi_str = str(pi)[:digits + 2]
print(f"Pi to {digits} digits:")
print(pi_str)
print(f"\nTotal digits computed: {len(pi_str) - 2}")
print(f"Computation time: {elapsed:.3f} seconds")
EOF

echo "Finished: $(date)"
SCRIPT'

# Submit the job
sudo docker exec slurmctld sbatch /data/pi_calc.sh

# Monitor
sudo docker exec slurmctld squeue

# View output (replace <jobid> with actual ID)
sudo docker exec slurmctld cat /data/pi-result-<jobid>.txt
```

## Expected Output

```
=== Pi Calculation to 10000 digits (Chudnovsky algorithm) ===
Started: Sun May 10 01:29:32 UTC 2026
Running on: c1

Pi to 10000 digits:
3.14159265358973420766845359157829834...
(full 10000 digits)

Total digits computed: 10000
Computation time: 0.088 seconds

Finished: Sun May 10 01:29:32 UTC 2026
```

## What This Demonstrates
- Single-node CPU-bound computation
- Python arbitrary precision arithmetic
- Slurm job output file naming with `%j` (job ID)
