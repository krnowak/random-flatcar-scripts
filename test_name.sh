#!/bin/bash

set -euo pipefail

grep -nrIHe "${1}" | cut -d/ -f 2 | sort -u
