# Sample Job 5: Fibonacci with Job Dependencies

## Overview
Demonstrates Slurm job dependencies by chaining three jobs: Job A computes Fibonacci numbers, Job B processes the results, and Job C summarizes. Each job waits for the previous one to complete.

## Job Scripts

### Job A: Compute Fibonacci numbers

```bash
#!/bin/bash
#SBATCH --job-name=fib-compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=fib-compute-%j.txt

echo "=== Job A: Fibonacci Computation ==="
echo "Started: $(date)"
echo "Running on: $(hostname)"
echo ""

python3 -c "
import time
import sys
sys.set_int_max_str_digits(1000000)

start = time.time()

def fibonacci(n):
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    return a

# Compute large Fibonacci numbers
results = []
for n in [1000, 5000, 10000, 50000, 100000]:
    fib = fibonacci(n)
    digits = len(str(fib))
    results.append((n, digits))
    print(f'F({n:>6}) has {digits:>6} digits')

elapsed = time.time() - start
print(f'\nComputation time: {elapsed:.3f} seconds')

# Write results to shared file for next job
with open('/data/fib_results.txt', 'w') as f:
    for n, d in results:
        f.write(f'{n},{d}\n')
print('Results written to /data/fib_results.txt')
"

echo ""
echo "Finished: $(date)"
```

### Job B: Analyze results

```bash
#!/bin/bash
#SBATCH --job-name=fib-analyze
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=fib-analyze-%j.txt

# Use a Here Document (<< 'EOF') so Bash ignores all quotes and special characters
python3 << 'EOF'
import math

with open("/data/fib_results.txt") as f:
    data = [line.strip().split(",") for line in f]

phi = (1 + math.sqrt(5)) / 2
log10_phi = math.log10(phi)

print(f"Analyzing {len(data)} Fibonacci entries")
# You can now use normal \n instead of chr(10)
print(f"\n{'n':>10} {'digits':>10} {'ratio':>10}")
print("-" * 35)

for n_str, d_str in data:
    n, d = int(n_str), int(d_str)
    ratio = d / n
    print(f"{n:>10} {d:>10} {ratio:>10.5f}")

print(f"\nDigits/n converges to log10(phi) = {log10_phi:.5f}")

with open("/data/fib_analysis.txt", "w") as f:
    f.write(f"log10_phi={log10_phi}\n")
    f.write(f"entries={len(data)}\n")
EOF
```

### Job C: Final summary

```bash
#!/bin/bash
#SBATCH --job-name=fib-summary
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=fib-summary-%j.txt

echo "=== Job C: Final Summary ==="
echo "Started: $(date)"
echo "Running on: $(hostname)"
echo ""

python3 -c "
print('=== Pipeline Complete ===')
print()

print('--- Raw Results (from Job A) ---')
with open('/data/fib_results.txt') as f:
    print(f.read())

print('--- Analysis (from Job B) ---')
with open('/data/fib_analysis.txt') as f:
    print(f.read())

print('Pipeline executed successfully across 3 dependent jobs.')
"

echo ""
echo "Finished: $(date)"
```

## How to Run

```bash
# Create all three job scripts
sudo docker exec slurmctld bash -c 'cat > /data/fib_compute.sh << "SCRIPT"
#!/bin/bash
#SBATCH --job-name=fib-compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=fib-compute-%j.txt

python3 -c "
import time
import sys
sys.set_int_max_str_digits(1000000)

start = time.time()

def fibonacci(n):
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    return a

results = []
for n in [1000, 5000, 10000, 50000, 100000]:
    fib = fibonacci(n)
    digits = len(str(fib))
    results.append((n, digits))
    print(f\"F({n:>6}) has {digits:>6} digits\")

elapsed = time.time() - start
print(f\"\nComputation time: {elapsed:.3f} seconds\")

with open(\"/data/fib_results.txt\", \"w\") as f:
    for n, d in results:
        f.write(f\"{n},{d}\n\")
print(\"Results written to /data/fib_results.txt\")
"
SCRIPT'

sudo docker exec slurmctld bash -c 'cat > /data/fib_analyze.sh << "SCRIPT"
#!/bin/bash
#SBATCH --job-name=fib-analyze
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=fib-analyze-%j.txt

python3 -c "
import math
with open(\"/data/fib_results.txt\") as f:
    data = [line.strip().split(\",\") for line in f]

phi = (1 + math.sqrt(5)) / 2
log10_phi = math.log10(phi)

print(f\"Analyzing {len(data)} Fibonacci entries\")
print(f\"{chr(10)}{'n':>10} {'digits':>10} {'ratio':>10}\")
print(\"-\" * 35)
for n_str, d_str in data:
    n, d = int(n_str), int(d_str)
    ratio = d / n
    print(f\"{n:>10} {d:>10} {ratio:>10.5f}\")

print(f\"{chr(10)}Digits/n converges to log10(phi) = {log10_phi:.5f}\")

with open(\"/data/fib_analysis.txt\", \"w\") as f:
    f.write(f\"log10_phi={log10_phi}\n\")
    f.write(f\"entries={len(data)}\n\")
"
SCRIPT'

sudo docker exec slurmctld bash -c 'cat > /data/fib_summary.sh << "SCRIPT"
#!/bin/bash
#SBATCH --job-name=fib-summary
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=fib-summary-%j.txt

echo "=== Pipeline Complete ==="
echo ""
echo "--- Raw Results (Job A) ---"
cat /data/fib_results.txt
echo ""
echo "--- Analysis (Job B) ---"
cat /data/fib_analysis.txt
echo ""
echo "All 3 jobs in dependency chain completed successfully."
SCRIPT'

# Submit with dependencies
JOB_A=$(sudo docker exec slurmctld sbatch --parsable /data/fib_compute.sh)
echo "Job A submitted: $JOB_A"

JOB_B=$(sudo docker exec slurmctld sbatch --parsable --dependency=afterok:$JOB_A /data/fib_analyze.sh)
echo "Job B submitted: $JOB_B (depends on $JOB_A)"

JOB_C=$(sudo docker exec slurmctld sbatch --parsable --dependency=afterok:$JOB_B /data/fib_summary.sh)
echo "Job C submitted: $JOB_C (depends on $JOB_B)"

# Watch the chain execute
sudo docker exec slurmctld squeue

# After completion, view the final summary
sudo docker exec slurmctld cat /data/fib-summary-<jobid>.txt
```

## Expected Output (Job C - Summary)

```
=== Pipeline Complete ===

--- Raw Results (Job A) ---
1000,209
5000,1045
10000,2090
50000,10450
100000,20899

--- Analysis (Job B) ---
log10_phi=0.20898764024997873
entries=5

All 3 jobs in dependency chain completed successfully.
```

## What This Demonstrates
- Job dependencies with `--dependency=afterok:<jobid>`
- Pipeline/workflow pattern (compute → analyze → summarize)
- Shared filesystem for inter-job communication (`/data/`)
- `--parsable` flag to capture job IDs for scripting
- Jobs execute in sequence, each waiting for the previous to succeed