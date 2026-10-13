#!/bin/bash
# test_all_distros.sh
#
# Runs each test file in TESTS across all 7 distros.
# Output: ./logs/<test_name>/<distro>.txt  (one file per distro)
#         stdout + stderr + valgrind report all in the same file.
#
# Usage:  ./test_all_distros.sh

set -e

BINARY="echelon"
LOG_ROOT="./logs"

TESTS=(
    "qsort_stress_test.ech"
    "collatz_stress_test.ech"
    "hashset_stress_test_fast.ech"
    "hashset_fixed_bucket_stress_test.ech"
    "graph_stress_test_optimised.ech"
    "recursive_fibonacci_38.ech"
    "memory_allocate_stress_test.ech"
    "memory_fill_stress_test.ech"
    "fibonacci_unbalanced_bin_tree.ech"
    "nested_16_levels_IF_ELSE.ech"
)

DISTROS=(
    "fedora-dev:latest"
    "ubuntu-dev:latest"
    "debian-dev:latest"
    "arch-dev:latest"
    "opensuse-dev:latest"
    "kali-dev:latest"
    "rockylinux-devel:latest"
)

mkdir -p "$LOG_ROOT"

for test in "${TESTS[@]}"; do
    test_name="$(basename "${test%.ech}")"
    out_dir="$LOG_ROOT/$test_name"
    mkdir -p "$out_dir"

    echo "=== Test: $test ==="

    for distro in "${DISTROS[@]}"; do
        distro_name="${distro/:/-}"
        out_file="$out_dir/${distro_name}.txt"

        echo "  -> $distro"

        docker run --rm \
            --security-opt seccomp=unconfined \
            -v "$(pwd)":/test:z \
            -w /test \
            --user root \
            "$distro" \
            bash -c "
                echo '=== Running on:' \$(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2)

                make clean 2>/dev/null || true
                make > /dev/null 2>&1
                strip -s $BINARY 2>/dev/null || true

                valgrind -s --leak-check=full ./$BINARY -f $test 2>&1
            " > "$out_file"
    done

    echo
done

echo "All tests completed."
echo "Logs in: $LOG_ROOT/"
