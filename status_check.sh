#!/bin/bash
echo -e "\e[34m===== IP Address Check =====\e[m"
IF_PROVIDER=enp1s0
IF_MGMT=enp6s0
INET_PROVIDER=$(ip -f inet -o addr show ${IF_PROVIDER} | cut -d\  -f 7 | cut -d/ -f 1)
echo -e "${IF_PROVIDER}: \e[32m${INET_PROVIDER}\e[m"
INET_MGMT=$(ip -f inet -o addr show ${IF_MGMT} | cut -d\  -f 7 | cut -d/ -f 1)
echo -e "${IF_MGMT}: \e[32m${INET_MGMT}\e[m"


echo -e "\e[34m===== Daemon Status Check =====\e[m"
SERVICE=chrony
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=mysql
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=rabbitmq
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=etcd
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi


echo -e "\e[34m===== Daemon Status Check (OpenStack) =====\e[m"
SERVICE=keystone
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=glance
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=nova-api
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=nova-conductor
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=nova-novncproxy
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=nova-scheduler
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=nova-compute
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=neutron-dhcp-agent
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=neutron-l3-agent
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=neutron-linuxbridge-agent
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=neutron-linuxbridge-cleanup
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=neutron-metadata-agent
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=neutron-ovs-cleanup
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=neutron-server
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=zun-api
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
SERVICE=zun-wsproxy
echo "${SERVICE}.service"
systemctl --quiet is-active ${SERVICE}.service
if [ $? -eq 0 ]; then
        echo -e "> \e[32mRunning\e[m"
else
        echo -e "> \e[31mDead\e[m"
fi
