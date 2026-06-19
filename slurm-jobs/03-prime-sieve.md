# Sample Job 3: Prime Number Sieve

## Overview
Finds all prime numbers up to 1,000,000 using the Sieve of Eratosthenes algorithm. Single-node memory-intensive computation.

## Job Script

```bash
#!/bin/bash
#SBATCH --job-name=prime-sieve
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=primes-%j.txt

echo "=== Prime Number Sieve (up to 1,000,000) ==="
echo "Started: $(date)"
echo "Running on: $(hostname)"
echo ""

python3 -c "
import time

def sieve_of_eratosthenes(limit):
    is_prime = [True] * (limit + 1)
    is_prime[0] = is_prime[1] = False
    for i in range(2, int(limit**0.5) + 1):
        if is_prime[i]:
            for j in range(i*i, limit + 1, i):
                is_prime[j] = False
    return [i for i in range(limit + 1) if is_prime[i]]

start = time.time()
primes = sieve_of_eratosthenes(1_000_000)
elapsed = time.time() - start

print(f'Found {len(primes):,} primes up to 1,000,000')
print(f'Computation time: {elapsed:.3f} seconds')
print(f'\nFirst 20 primes: {primes[:20]}')
print(f'Last 20 primes: {primes[-20:]}')
print(f'\nLargest prime under 1M: {primes[-1]}')
"

echo ""
echo "Finished: $(date)"
```

## How to Run

```bash
# Copy the job script into the controller
sudo docker exec slurmctld bash -c 'cat > /data/prime_sieve.sh << "SCRIPT"
#!/bin/bash
#SBATCH --job-name=prime-sieve
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=primes-%j.txt

echo "=== Prime Number Sieve (up to 1,000,000) ==="
echo "Started: $(date)"
echo "Running on: $(hostname)"
echo ""

python3 -c "
import time

def sieve_of_eratosthenes(limit):
    is_prime = [True] * (limit + 1)
    is_prime[0] = is_prime[1] = False
    for i in range(2, int(limit**0.5) + 1):
        if is_prime[i]:
            for j in range(i*i, limit + 1, i):
                is_prime[j] = False
    return [i for i in range(limit + 1) if is_prime[i]]

start = time.time()
primes = sieve_of_eratosthenes(1_000_000)
elapsed = time.time() - start

print(f\"Found {len(primes):,} primes up to 1,000,000\")
print(f\"Computation time: {elapsed:.3f} seconds\")
print(f\"\nFirst 20 primes: {primes[:20]}\")
print(f\"Last 20 primes: {primes[-20:]}\")
print(f\"\nLargest prime under 1M: {primes[-1]}\")
"

echo ""
echo "Finished: \$(date)"
SCRIPT'

# Submit the job
sudo docker exec slurmctld sbatch /data/prime_sieve.sh

# Monitor
sudo docker exec slurmctld squeue

# View output
sudo docker exec slurmctld cat /data/primes-<jobid>.txt
```

## Expected Output

```
=== Prime Number Sieve (up to 1,000,000) ===
Started: Sun May 10 01:29:56 UTC 2026
Running on: c1

Found 78,498 primes up to 1,000,000
Computation time: 0.066 seconds

First 20 primes: [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71]
Last 20 primes: [999671, 999683, 999721, 999727, 999749, 999763, 999769, 999773, 999809, 999853, 999863, 999883, 999907, 999917, 999931, 999953, 999959, 999961, 999979, 999983]

Largest prime under 1M: 999983

Finished: Sun May 10 01:29:56 UTC 2026
```

## What This Demonstrates
- Single-node memory-bound computation
- Classic algorithm implementation
- Fast execution for benchmarking
