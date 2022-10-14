#!/bin/bash
IF_PROVIDER=enp6s0
IF_MGMT=enp1s0
if [ $# != 1 ]; then
    echo "Usage: ./${PROGRAM} [mode]"
    echo "  mode: controller, compute"
    exit 0;
fi
MODE=${1}

echo -e "\e[34m===== IP Address Check =====\e[m"
INET_PROVIDER=$(ip -f inet -o addr show ${IF_PROVIDER} | cut -d\  -f 7 | cut -d/ -f 1)
echo -e "${IF_PROVIDER}: \e[32m${INET_PROVIDER}\e[m"
INET_MGMT=$(ip -f inet -o addr show ${IF_MGMT} | cut -d\  -f 7 | cut -d/ -f 1)
echo -e "${IF_MGMT}: \e[32m${INET_MGMT}\e[m"

# status check
func () {
    SERVICE=$1
    systemctl --quiet is-active ${SERVICE}.service
    if [ $? -eq 0 ]; then
        echo -e "${SERVICE}.service: \e[32mactive (running)\e[m"
    else
        echo -e "${SERVICE}.service: \e[31mfailed\e[m"
    fi
}

# main
systemctl restart systemd-networkd
if [ ${MODE} = "controller" -o ${MODE} = "con" ]; then
    basic_service=(chrony mysql rabbitmq-server etcd)
    os_service=(glance-api \
                   nova-api nova-conductor nova-novncproxy nova-scheduler nova-compute \
                   neutron-dhcp-agent neutron-l3-agent neutron-linuxbridge-agent \
                   neutron-linuxbridge-cleanup neutron-metadata-agent \
                   neutron-server zun-api zun-wsproxy)
elif [ ${MODE} = "compute" -o ${MODE} = "com" ]; then
    basic_service=(chrony)
    os_service=(nova-compute \
                   docker containerd kuryr-libnetwork \
                   neutron-linuxbridge-cleanup neutron-linuxbridge-agent \
                   zun-cni-daemon zun-compute)
else
    echo "Usage: ./${PROGRAM} [mode]"
    echo "  mode: controller, compute"
    exit 0;
fi

echo -e "\e[34m===== Daemon Status Check =====\e[m"
for i in "${basic_service[@]}"
do
    func ${i}
done

echo -e "\e[34m===== Daemon Status Check (OpenStack) =====\e[m"
for i in "${os_service[@]}"
do
    func ${i}
done

