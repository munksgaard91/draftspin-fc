#!/bin/bash
# Kør alle automatiske tests: ./tests/run.sh   (kræver deno: brew install deno)
cd "$(dirname "$0")/.." && deno test --no-lock --allow-read tests/
