#!/bin/bash
# test_all_distros.sh
#
# Runs a test file on all 7 distros (6 + Rocky).
# Saves one program log + one valgrind log per distro into ./logs/
#
# Usage: ./test_all_distros.sh [test_file.ech]
#        defaults to parallel_fibonacci.ech

set -e

TEST_FILE="${1:-parallel_fibonacci.ech}"
BINARY="echelon"
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"

DISTROS=(
    "fedora-dev:latest"
    "ubuntu-dev:latest"
    "debian-dev:latest"
    "arch-dev:latest"
    "opensuse-dev:latest"
    "kali-dev:latest"
    "rockylinux-devel:latest"
)

for distro in "${DISTROS[@]}"; do
    distro_name="${distro/:/-}"
    echo "Testing on $distro..."

    docker run --rm \
        --security-opt seccomp=unconfined \
        -v "$(pwd)":/test:z \
        -w /test \
        --user root \
        "$distro" \
        bash -c "
            echo '=== Running on:' \$(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2)

            # build fresh inside the container
            make clean 2>/dev/null || true
            make > /dev/null 2>&1
            strip -s $BINARY 2>/dev/null || true

            # run the test under valgrind, capture logs
            valgrind -s --leak-check=full --trace-children=yes \
                --log-file=\"$LOG_DIR/valgrind_${distro_name}.log\" \
                ./$BINARY -f $TEST_FILE > \"$LOG_DIR/program_${distro_name}.log\" 2>&1
        "

    echo "Done: $distro_name"
done

echo
echo "All tests completed."
echo "Program outputs: $LOG_DIR/program_*.log"
echo "Valgrind logs:   $LOG_DIR/valgrind_*.log"
