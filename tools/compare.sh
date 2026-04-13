#!/bin/bash
# Compare our assembler output with reference REL files
# Usage: ./tools/compare.sh

BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
AS="$BASEDIR/build/as"
REFDIR="$BASEDIR/reference"
WORKDIR="$BASEDIR/build/verify"
DECODE="$BASEDIR/tools/rel_decode.py"

mkdir -p "$WORKDIR"

PASS=0
FAIL=0

for ref_asm in "$REFDIR"/*.ASM; do
    base=$(basename "$ref_asm" .ASM)
    ref_rel="$REFDIR/$base.REL"

    if [ ! -f "$ref_rel" ]; then
        echo "SKIP: $base (no reference .REL)"
        continue
    fi

    # Copy ASM to work dir and assemble
    cp "$ref_asm" "$WORKDIR/$base.ASM"
    cd "$WORKDIR"

    output=$(perl -e 'alarm 10; exec @ARGV' "$AS" "$base.ASM" 2>&1)
    exit_code=$?
    our_rel="$WORKDIR/$base.REL"

    errors=$(echo "$output" | grep "error(s)" | grep -o "^[0-9]*")

    if [ "$errors" != "0" ] && [ -n "$errors" ]; then
        echo "FAIL: $base - $errors errors during assembly"
        echo "$output" | grep "Error in line" | head -5
        FAIL=$((FAIL + 1))
        continue
    fi

    if [ ! -f "$our_rel" ]; then
        echo "FAIL: $base - no .REL output"
        FAIL=$((FAIL + 1))
        continue
    fi

    # Compare sizes
    ref_size=$(wc -c < "$ref_rel")
    our_size=$(wc -c < "$our_rel")

    if cmp -s "$our_rel" "$ref_rel"; then
        echo "PASS: $base ($ref_size bytes, identical)"
        PASS=$((PASS + 1))
    else
        echo "DIFF: $base (ref=$ref_size bytes, our=$our_size bytes)"
        # Show first difference
        diff <(xxd "$ref_rel") <(xxd "$our_rel") | head -8
        FAIL=$((FAIL + 1))
    fi

    cd "$BASEDIR"
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
