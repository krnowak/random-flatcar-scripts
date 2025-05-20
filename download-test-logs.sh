#!/bin/bash

##
## download-test-logs.sh [-a <ARCH>] [-p <PLATFORM>] [-f
## <GREP_FILTERS>] [-l <LOG_FILES>] <VERSION_ID> <BUILD_ID>
## <DIRECTORY>
##
## Downloads test logs.
##
## Flags:
##
## -a <ARCH> - architecture, defaults to amd64
## -f <GREP_FILTERS> - filters to apply to a list of test names for a
##                     given arch and platform
## -h - print this help
## -k - keep .rubbish directory
## -l <LOG_FILES> - comma-separated list of log files to download for
##                  each test case, defaults to
##                  console.txt,ignition.json,journal-raw.txt.gz,journal.txt
## -p <PLATFORM> - platform, defaults to qemu
##
## Positional parameters:
##
## 0 - version ID, just numbers like 3802.0.0
## 1 - build ID, may be empty
## 2 - output directory where the log files will be stored
##

set -euo pipefail

arch=amd64
platform=qemu
filter='.'
print_help=''
logs='console.txt,ignition.json,journal-raw.txt.gz,journal.txt'
keep_rubbish=''

while [[ ${#} -gt 0 ]]; do
    case ${1} in
        -a) arch=${2}; shift 2;;
        -f) filter=${2}; shift 2;;
        -h) print_help=x; shift;;
        -k) keep_rubbish=x; shift;;
        -l) logs=${2}; shift 2;;
        -p) platform=${2}; shift 2;;
        --) shift; break;;
        -*) echo "unknown flag ${1}" >&2; exit 1;;
        *) break;;
    esac
done

if [[ -n ${print_help} ]]; then
    grep '^##' "${0}" | sed -e 's/^##[[:space:]]*//'
    exit 0
fi

function pref_suf {
    local prefix=${1}; shift
    local suffix=${1}; shift

    local -a lines1=( "${@}" )
    local -a lines2=( "${lines1[@]/#/${prefix}}" )
    lines1=( "${lines2[@]/%/${suffix}}" )

    printf '%s\n' "${lines1[@]}"
}

mapfile -t logs_arr <<<"${logs//,/$'\n'}"

version_id=${1}; shift
build_id=${1}; shift
dir=${1}; shift

if [[ ${#} -gt 0 ]]; then
    echo "Too many positional parameters: ${*@Q}" >&2
    exit 1
fi

version="${version_id}${build_id:++}${build_id}"

url="https://bincache.flatcar-linux.net/testing/${version}/${arch}/${platform}/_kola_temp"

rubbish="${dir}/.rubbish"
mkdir -p "${rubbish}"

a_href_dot_slash_urls() {
    # sed command: drop all lines not matching `a href="./${name}/"`,
    # extract name from url (dequoting and dropping leading `./` and
    # trailing `/`)
    sed -e '/a href="\.\/[^"]*\/"/ ! d; s#^.*<a href="\./\([^"]*\)/".*$#\1#' "${@}"
}

l1="${rubbish}/kola_tmp_listing"
wget -O "${l1}" "${url}/"
runs=()
mapfile -t runs < <(a_href_dot_slash_urls "${l1}" | grep -e '-[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{4\}-[0-9]*$')

tests=()

ftdb="${rubbish}/files-to-download"
ftd1="${ftdb}-l1"

pref_suf "${url}/" '/' "${runs[@]}" >"${ftd1}"
wget --input-file="${ftd1}" --directory-prefix="${rubbish}/run-listings" --force-directories --no-host-directories --cut-dirs=5

run_tests=()
for run in "${runs[@]}"; do
    l2="${rubbish}/run-listings/${run}/index.html"
    mapfile -t tests < <(a_href_dot_slash_urls "${l2}" | grep -v -F -x -e 'reports' | grep -e "${filter}")
    run_tests+=( "${tests[@]/#/${run}/}" )
done
ftd2="${ftdb}-l2"
pref_suf "${url}/" '/' "${run_tests[@]}" >"${ftd2}"

wget --input-file="${ftd2}" --directory-prefix="${rubbish}/run-test-listings" --force-directories --no-host-directories --cut-dirs=5

run_test_machines=()
for run_test in "${run_tests[@]}"; do
    l3="${rubbish}/run-test-listings/${run_test}/index.html"
    mapfile -t machines < <(a_href_dot_slash_urls "${l3}")
    run_test_machines+=( "${machines[@]/#/${run_test}/}" )
done

ftd3="${ftdb}-l3"
truncate --size=0 "${ftd3}"
for run_test_machine in "${run_test_machines[@]}"; do
    pref_suf "${url}/${run_test_machine}/" '' "${logs_arr[@]}" >>"${ftd3}"
done

wget --input-file="${ftd3}" --directory-prefix="${dir}" --force-directories --no-host-directories --cut-dirs=5
if [[ -z ${keep_rubbish} ]]; then
    rm -rf "${rubbish}"
fi
