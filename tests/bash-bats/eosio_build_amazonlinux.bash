#!/usr/bin/env bats
load helpers/general
export SCRIPT_LOCATION="scripts/eosio_build.bash"
export TEST_LABEL="[eosio_build_amazonlinux]"

[[ $ARCH == "Linux" ]] || exit 0 # Skip if we're not on linux
( [[ $NAME == "Amazon Linux AMI" ]] || [[ $NAME == "Amazon Linux" ]] ) || exit 0 # Exit 0 is required for pipeline

# A helper function is available to show output and status: `debug`

# Testing Root user
./tests/bash-bats/modules/root-user.bash
# Testing Options
./tests/bash-bats/modules/dep_script_options.bash
# Testing CMAKE
./tests/bash-bats/modules/cmake.bash
# Testing Clang
./tests/bash-bats/modules/clang.bash
# Testing MongoDB
./tests/bash-bats/modules/mongodb.bash

## Needed to load eosio_build_ files properly; it can be empty
@test "${TEST_LABEL} > General" {
    set_system_vars # Obtain current machine's resources and set the necessary variables (like JOBS, etc)

    # no which!
    run bash -c "printf \"n\n%.0s\" {1..2} | ./$SCRIPT_LOCATION -P"
    [[ "${output##*$'\n'}" =~ "Please install the 'which' command before proceeding" ]] || exit

    # No c++!
    run bash -c "printf \"y\nn\nn\n\" | ./${SCRIPT_LOCATION}"
    [[ ! -z $(echo "${output}" | grep "Unable to find compiler \"c++\"! Pass in the -P option if you wish for us to install it OR set \$CXX to the proper binary location.") ]] || exit


    run bash -c "printf \"y\n%.0s\" {1..100} | ./$SCRIPT_LOCATION -P"
    [[ ! -z $(echo "${output}" | grep "Executing: make -j${JOBS}") ]] || exit
    ### Make sure deps are loaded properly
    [[ ! -z $(echo "${output}" | grep "Executing: cd ${SRC_DIR}") ]] || exit
    [[ ! -z $(echo "${output}" | grep "Starting EOSIO Dependency Install") ]] || exit
    [[ ! -z $(echo "${output}" | grep "Executing: /usr/bin/yum -y update") ]] || exit
    if [[ $NAME == "Amazon Linux" ]]; then
        [[ ! -z $(echo "${output}" | grep "libstdc++.*found!") ]] || exit
    elif [[ $NAME == "Amazon Linux AMI" ]]; then
        [[ ! -z $(echo "${output}" | grep "make.*found!") ]] || exit
    fi
    [[ ! -z $(echo "${output}" | grep "sudo.*NOT.*found.") ]] || exit
    [[ ! -z $(echo "${output}" | grep ${HOME}.*/src/boost) ]] || exit
    [[ ! -z $(echo "${output}" | grep "Starting EOSIO Build") ]] || exit
    [[ ! -z $(echo "${output}" | grep "make -j${CPU_CORES}") ]] || exit
    [[ -z $(echo "${output}" | grep "MongoDB C++ driver successfully installed") ]] || exit # Mongo is off
    # Ensure PIN_COMPILER=false uses proper flags for the various installs
    install-package gcc-c++ BYPASS_DRYRUN &>/dev/null
    run bash -c "./$SCRIPT_LOCATION -y"
    [[ ! -z $(echo "${output}" | grep " -G 'Unix Makefiles'") ]] || exit # CMAKE
    [[ ! -z $(echo "${output}" | grep " --with-iostreams --with-date_time") ]] || exit # BOOST
    uninstall-package gcc-c++ BYPASS_DRYRUN &>/dev/null
}