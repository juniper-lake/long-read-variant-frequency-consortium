#!/bin/bash --login
# This script is run from Dockerfile
# The --login ensures the bash configuration is loaded, enabling Conda.

set -euo pipefail

# Activate conda environment
source ~/.bashrc

# Pass docker run arguments through
exec "$@"
