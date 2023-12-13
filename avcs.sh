#!/bin/bash

set -euo pipefail

#after='2023-11-30-1401-66'
after='0000-00-00-0000-00'

while [[ ${#} -gt 0 ]]; do
    case ${1} in
        -a) after=${2}; shift 2;;
        --) shift; break;;
        -*) echo "unknown flag ${1}" >&2; exit 1;;
        *) break;;
    esac
done

mapfile -t after_fields <<<"${after//-/$'\n'}"
if [[ ${#after_fields[@]} -ne 5 ]]; then
    echo 'invalid -a value, should be in form of yyyy-mm-dd-hhmm-ss' >&2
    exit 1
fi

shopt -s extglob

dir=${1%%*(/)}; shift
printf 'avcs in %s\n' "${dir@Q}" >&2

dirs=()
for r in "${dir}/"*; do
    d=${r##*/}
    f=${d#*-}
    mapfile -t f_fields <<<"${f//-/$'\n'}"
    if [[ ${#f_fields[@]} -ne 5 ]]; then
        echo "ignoring ${d@Q}, invalid fields in name" >&2
        exit 1
    fi
    add=
    for ((i = 0; i < ${#f_fields[@]}; i++ )); do
        c=${f_fields["${i}"]}
        a=${after_fields["${i}"]}
        if [[ ${c} -lt ${a} ]]; then
            break
        fi
        if [[ ${c} -gt ${a} ]]; then
            add=x
            break
        fi
    done
    if [[ -n ${add} ]]; then
        dirs+=( "${r}" )
    fi
done

{
    printf 'using following dirs\n'
    printf '  %s\n' "${dirs[@]}"
    printf '\n'
} >&2

find "${dirs[@]}" -name journal.txt -exec cat {} \; | \
    grep -ie 'avc:[[:space:]]*denied' "${@/%//all-logs.txt}" | \
    sed \
        -e 's/^.*avc:/avc:/' \
        -e 's/\(ino\|pid\)=[0-9]*/\1=[0-9]*/g' \
        -e 's/c[0-9]*,c[0-9]*/c[0-9]*,c[0-9]*/g' | \
    sort -u
