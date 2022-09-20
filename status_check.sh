#!/bin/bash
echo -e "\e[34m===== IP Address Check =====\e[m"
IF_PROVIDER=enp1s0
IF_MGMT=enp6s0
INET_PROVIDER=$(ip -f inet -o addr show ${IF_PROVIDER} | cut -d\  -f 7 | cut -d/ -f 1)
echo -e "${IF_PROVIDER}: \e[32m${INET_PROVIDER}\e[m"
INET_MGMT=$(ip -f inet -o addr show ${IF_MGMT} | cut -d\  -f 7 | cut -d/ -f 1)
echo -e "${IF_MGMT}: \e[32m${INET_MGMT}\e[m"


func () {
    SERVICE=$1
    echo "${SERVICE}.service"
    systemctl --quiet is-active ${SERVICE}.service
    if [ $? -eq 0 ]; then
            echo -e "> \e[32mRunning\e[m"
    else
            echo -e "> \e[31mDead\e[m"
    fi
}

echo -e "\e[34m===== Daemon Status Check =====\e[m"
service_array=(chrony mysql rabbitmq-server etcd)
for i in "${service_array[@]}"
do
    func ${i}
done

echo -e "\e[34m===== Daemon Status Check (OpenStack) =====\e[m"
service_array=(glance-api \
               nova-api nova-conductor nova-novncproxy nova-scheduler nova-compute \
               neutron-dhcp-agent neutron-l3-agent neutron-linuxbridge-agent \
               neutron-linuxbridge-cleanup neutron-metadata-agent neutron-ovs-cleanup \
               neutron-server zun-api zun-wsproxy)
for i in "${service_array[@]}"
do
    func ${i}
done

