#!/bin/bash

#
# Usage: docker/build_container_and_run_tests.sh lua5.2
#

set -e
bindir="$(dirname $0)"
$bindir/build_container.sh "$@"
$bindir/run_tests_in_container.sh "$@"
