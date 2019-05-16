#!/usr/bin/env bats
load helpers/general

export SCRIPT_LOCATION="scripts/eosio_build.bash"
export TEST_LABEL="[eosio_build_centos]"

[[ $ARCH == "Linux" ]] || exit 0 # Exit 0 is required for pipeline
[[ $NAME == "CentOS Linux" ]] || exit 0 # Exit 0 is required for pipeline

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
    run bash -c "printf \"y\ny\nn\n\" | ./${SCRIPT_LOCATION}"
    [[ ! -z $(echo "${output}" | grep "Unable to find compiler \"c++\"! Pass in the -P option if you wish for us to install it OR set \$CXX to the proper binary location.") ]] || exit

    execute-always yum -y --enablerepo=extras install centos-release-scl &>/dev/null
    install-package devtoolset-7 BYPASS_DRYRUN &>/dev/null
    # Ensure SCL and devtoolset-7 for c++ binary installation
    run bash -c "printf \"y\n%.0s\" {1..100}| ./${SCRIPT_LOCATION}"
    [[ ! -z $(echo "${output}" | grep "centos-release-scl-2-3.el7.centos.noarch found") ]] || exit
    [[ ! -z $(echo "${output}" | grep "devtoolset-7-7.1-4.el7.x86_64 found") ]] || exit
    [[ ! -z $(echo "${output}" | grep "Executing: source /opt/rh/devtoolset-7/enable") ]] || exit
    [[ ! -z $(echo "${output}" | grep "Executing: make -j${JOBS}") ]] || exit
    [[ ! -z $(echo "${output}" | grep "Starting EOSIO Dependency Install") ]] || exit
    [[ ! -z $(echo "${output}" | grep "Executing: /usr/bin/yum -y update") ]] || exit
    [[ ! -z $(echo "${output}" | grep "Python36 successfully enabled") ]] || exit
    [[ ! -z $(echo "${output}" | grep "python.*found!") ]] || exit
    [[ ! -z $(echo "${output}" | grep "Ensuring CMAKE") ]] || exit
    [[ ! -z $(echo "${output}" | grep ${HOME}.*/src/boost) ]] || exit
    [[ ! -z $(echo "${output}" | grep "Starting EOSIO Build") ]] || exit
    [[ ! -z $(echo "${output}" | grep "make -j${CPU_CORES}") ]] || exit
    [[ ! -z $(echo "${output}" | grep "EOSIO has been successfully built") ]] || exit
    uninstall-package devtoolset-7* BYPASS_DRYRUN &>/dev/null
    uninstall-package centos-release-scl BYPASS_DRYRUN &>/dev/null

}