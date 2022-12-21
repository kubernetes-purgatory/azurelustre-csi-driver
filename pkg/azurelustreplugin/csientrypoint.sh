#!/bin/bash

# Copyright 2022 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Shell script to install Lustre client kernel modules and launch CSI driver
#   $1 is the path to the CSI driver.
#

set -o xtrace
set -o errexit
set -o pipefail
set -o nounset

installClientPackages=${AZURELUSTRE_CSI_INSTALL_LUSTRE_CLIENT:-yes}
echo "installClientPackages: ${installClientPackages}"

requiredLustreVersion=${LUSTRE_VERSION:-"2.15"}
echo "requiredLustreVersion: ${requiredLustreVersion}"

echo "$(date -u) Command line arguments: $@"

if [[ "${installClientPackages}" == "yes" ]]; then

  osReleaseCodeName=$(lsb_release -cs)
  kernelVersion=$(uname -r)
  
  echo "$(date -u) Installing Lustre client packages for OS=${osReleaseCodeName}, kernel=${kernelVersion} "

  curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/amlfs/ ${osReleaseCodeName} main" | tee /etc/apt/sources.list.d/amlfs.list
  apt-get update

  # Install Lustre client module
  lustreClientModulePackageVersion=$(apt list -a lustre-client-modules-${kernelVersion} | awk '{print $2}' | grep ^${requiredLustreVersion} | sort -u -V | tail -n 1  || true)

  if [[ -z $lustreClientModulePackageVersion ]]; then
    echo "can't find package lustre-client-modules-${kernelVersion} for Lustre version $requiredLustreVersion in Microsoft Linux Repo, exiting"
    exit 1
  fi

  echo "$(date -u) Installing Lustre client modules: lustre-client-modules-${kernelVersion}=$lustreClientModulePackageVersion"

  # grub issue
  # https://stackoverflow.com/questions/40748363/virtual-machine-apt-get-grub-issue/40751712
  DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" \
    lustre-client-modules-${kernelVersion}=$lustreClientModulePackageVersion

  # Install Lustre Client Util package only for Lustre 2.14
  lustreClientUtilsPackageVersion=$(apt list -a lustre-client-utils | awk '{print $2}' | grep ^${requiredLustreVersion} | sort -u -V | tail -n 1 || true)

  if [[ -z $lustreClientUtilsPackageVersion && "$requiredLustreVersion" == "2.14" ]]; then
    echo "can't find package lustre-client-utils for Lustre version $requiredLustreVersion in Microsoft Linux Repo, exiting"
    exit 1
  fi

  if [[ ! -z $lustreClientUtilsPackageVersion && "$requiredLustreVersion" == "2.14" ]]; then
    echo "$(date -u) Installing Lustre client utils: lustre-client-utils=$lustreClientUtilsPackageVersion"
    DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" \
      lustre-client-utils=$lustreClientUtilsPackageVersion
  fi

  echo "$(date -u) Installed Lustre client packages."

  echo "$(date -u) Enabling Lustre client kernel modules."

  modprobe -v ksocklnd
  modprobe -v lnet
  modprobe -v mgc
  modprobe -v lustre

  # For some reason, this is a false positive before we restart the container
  # The volume mount succeeds later even this returns a failure
  # We need to revisit this after moving the script to run on AKS node
  lctl network up || true

  echo "$(date -u) Enabled Lustre client kernel modules."

fi

echo "$(date -u) Entering Lustre CSI driver"

echo Executing: azurelustreplugin ${2-} ${3-} ${4-} ${5-} ${6-} ${7-} ${8-} ${9-}
./azurelustreplugin ${2-} ${3-} ${4-} ${5-} ${6-} ${7-} ${8-} ${9-}

echo "$(date -u) Exiting Lustre CSI driver"
