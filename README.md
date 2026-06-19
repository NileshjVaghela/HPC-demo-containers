HPC with Slurm - Small Workable Demo Howto
==========================================
Written in plain language. No fluff.


WHAT ARE WE BUILDING?
---------------------
A tiny HPC cluster with:
  - 1 controller node (the boss)
  - 2 worker nodes (the workers)
  - Shared storage so everyone sees the same files
  - Slurm doing the job scheduling

We'll use Docker Compose because it's the fastest way to get this running
without dealing with actual VMs or physical machines.


WHAT YOU NEED BEFORE STARTING
------------------------------
  - Docker + Docker Compose installed on your machine
  - Git
  - A terminal
  - About 15-20 minutes

That's it. No cloud account, no extra hardware.
