#!/bin/sh
echo "Check if virtualization is supported."
CHECK=$(egrep -c '(vmx|svm)' /proc/cpuinfo)
if [ ${CHECK} -gt 0 ]; then
        echo "\e[32mOK: ${CHECK}\e[m"
else
        echo "\e[31mNG: ${CHECK}\e[m"
        exit 0;
fi

# usage: ./create_ubuntu2004.sh [NAME] [RAM]MB [vCPU] [DISK]GB [NETWORK_IF]
PROGRAM=`basename $0`
NAME=${1}
RAM=${2}
vCPU=${3}
DISK=${4}
NETWORK_IF=${5}
# /var/lib/libvirt/images/*.qcow2 (ver.GUI)
IMAGE_DIR=/var/kvm/images

if [ $# != 5 ]; then
        echo "Usage: ./${PROGRAM} [NAME] [RAM] [vCPU] [DISK] [NETWORK_IF]"
        echo "Example: ./${PROGRAM} Host 2048 1 25 virbr0"
        exit 0;
fi

if [ -f ${IMAGE_DIR}/${NAME}.qcow2 ]; then
        echo "\e[31mExists ${NAME}.qcow2. exit.\e[m"
        exit 1;
fi

echo "\e[32m${IMAGE_DIR}/${NAME}.qcow2 creating...\e[m"
qemu-img create -f qcow2 ${IMAGE_DIR}/${NAME}.qcow2 ${DISK}G
if [ $? != 0 ]; then
        echo "\e[31m!!! Maybe adding sudo will help. !!!\e[m"
        exit 1;
fi

echo "\e[32mStart virt-install\e[m"
virt-install \
    --name ${NAME} \
    --accelerate \
    --hvm \
    --ram ${RAM} \
    --vcpus ${vCPU} \
    --os-variant ubuntu20.04 \
    --disk path=${IMAGE_DIR}/${NAME}.qcow2,format=qcow2 \
    --network bridge=${NETWORK_IF},model=virtio \
    --nographics \
    --location /home/yokoo/iso/ubuntu-20.04.5-live-server-amd64.iso,kernel=casper/vmlinuz,initrd=casper/initrd \
    --extra-args "console=ttyS0,115200n8 keymap=ja"
if [ $? != 0 ]; then
        echo "\e[31m!!! Installation failed. !!!\e[m"
        echo "\e[31m!!! Removing ${IMAGE_DIR}/${NAME}.qcow2 !!!\e[m"
        rm ${IMAGE_DIR}/${NAME}.qcow2
        exit 1;
fi

