---
tags: OpenStack
---
# OpenStack構築メモ
- [OpenStack Installation Guide](https://docs.openstack.org/install-guide/index.html)
- 表示しているパスワードはテスト用である
---
# 事前準備
- KVMハイパーバイザーでOpenStack環境を構築するにあたっての事前準備

- Controller Node ・ Compute Node
    - ホストマシンからのコンソール接続を有効化
        ```
        $ sudo systemctl enable serial-getty@ttyS0.service
        $ sudo systemctl start serial-getty@ttyS0.service
        ```
    - パッケージの更新
        ```
        $ sudo apt update && sudo apt upgrade -y
        ```
    - open-ssh-server、vim
        ```
        $ sudo apt install -y openssh-server vim
        ```
    - NIC の追加
        - br165: 165.242.125.0/24を延長したBridge
        - virbr0: 10.0.0.0/24をNATするDefault　Bridge
        ```
        ホストで実行
        $ virsh attach-interface --type bridge --source virbr0 --model virtio --persistent controller10
        Interface attached successfully

        $ virsh attach-interface --type bridge --source virbr0 --model virtio --persistent compute10
        Interface attached successfully

        $ virsh domiflist controller10
         Interface   Type     Source   Model    MAC
        -----------------------------------------------------------
         vnet1       bridge   br165    virtio   52:54:00:ce:f6:6f
         vnet2       bridge   virbr0   virtio   52:54:00:70:09:a5

        $ virsh domiflist compute10
         Interface   Type     Source   Model    MAC
        -----------------------------------------------------------
         vnet0       bridge   br165    virtio   52:54:00:92:71:99
         vnet3       bridge   virbr0   virtio   52:54:00:52:b0:c0
        ```
        ```
        VM内で実行 (確認)
        netsci@compute10:~$ ip a
        1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
            link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
            inet 127.0.0.1/8 scope host lo
               valid_lft forever preferred_lft forever
            inet6 ::1/128 scope host 
               valid_lft forever preferred_lft forever
        2: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
            link/ether 52:54:00:92:71:99 brd ff:ff:ff:ff:ff:ff
            inet 165.242.125.131/24 brd 165.242.125.255 scope global dynamic noprefixroute enp1s0
               valid_lft 408sec preferred_lft 408sec
            inet6 2001:2f8:1c2:125:a6f7:2994:4387:d2a2/64 scope global temporary dynamic 
               valid_lft 603184sec preferred_lft 84627sec
            inet6 2001:2f8:1c2:125:ee49:efc2:47d:804f/64 scope global dynamic mngtmpaddr noprefixroute 
               valid_lft 2591856sec preferred_lft 604656sec
            inet6 fe80::8118:3c4f:95d8:f192/64 scope link noprefixroute 
               valid_lft forever preferred_lft forever
        3: enp6s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
            link/ether 52:54:00:52:b0:c0 brd ff:ff:ff:ff:ff:ff
            inet6 fe80::812d:6a97:391f:bd7a/64 scope link noprefixroute 
               valid_lft forever preferred_lft forever
        ```
    - アドレスの固定
        - 10.0.0.10: Controller Node
        - 10.0.0.20: Compute Node
        ```
        $ sudo vim /etc/netplan/99-netcfg.yaml
        ```
        ```
        network:
          version: 2
          ethernets:
            enp6s0:
              addresses: [10.0.0.10/24]
              gateway4: 10.0.0.1
              nameservers:
                addresses: [165.242.125.40]
        ```
    - アドレスなし設定
        - 165.242.125.0/24のNWに接続されているNICはunnumbered
        ```
        $ sudo vim /etc/systemd/network/enp1s0.network 
        ```
        ```
        [Match]
        Name=enp1s0

        [Network]
        LinkLocalAddressing=no
        IPv6AcceptRA=no
        ```
        ```
        $ systemctl restart systemd-networkd
        ```
        > :warning:　ipv6 global dynamic mngtmpaddr と link local がついてしまう

---
# 概要
## ハードウェア要件
- OpenStackを使ってインスタンスを起動するためには、最低限２つのノードが必要

- **Controller Node**
    - Identity サービス、Image サービス、Placement サービス、Compute の管理部分、Networking の管理部分、さまざまな Networking エージェント、およびダッシュボードを実行する。
        - 1-2 CPU (4)
        - 8GB RAM (8)
        - 100GB Storage (50)
        - 2 NIC (2)
- **Compute Node**
    - インスタンスを操作する Compute のハイパーバイザー部分を実行します。デフォルトでは、Compute は KVMハイパーバイザーを使用します。
    - 今回は doker コンテナを利用する。
        - 2-4 CPU (1)
        - 8+GB RAM (4)
        - 100+GB Storage (50)
        - 2 NIC (2)

## ネットワーキング
- オプション２: Self-service Networks

![](./img/NpEvV3m.jpg)
![](./img/0aklB7L.png)


## ネットワークレイアウト

![](./img/7RMMhLR.png)

---
# 事前環境構築
## コントローラノード / コンピュートノード
- 名前解決
    ```
    $ sudo vim /etc/hosts
    ```
    ```
    # controller
    10.0.0.10       controller

    # compute10
    10.0.0.20       compute10
    ```

## NTP
- コントローラノード
    ```
    $ apt install chrony
    ```
    ```
    $ vim /etc/chrony/chrony.conf
    ```
    ```
    server ntp.nict.jp iburst
    allow 10.0.0.0/24
    ```
    > その他のサーバはコメントアウト
    ```
    $ service chrony restart
    ```
- その他のノード
    ```
    $ apt install chrony
    ```
    ```
    $ vim /etc/chrony/chrony.conf
    ```
    ```
    server controller iburst
    ```
    > その他のサーバはコメントアウト
    ```
    $ service chrony restart
    ```
- 確認
    ```
    $ chronyc sources
    ```

## OpenStack パッケージ
> 全てのノード
- アーカイブの有効化
    ```
    $ add-apt-repository cloud-archive:victoria
    ```
    > 以下はこのタイミングで必要なのか？
    ```
    $ apt install nova-compute
    $ apt install python3-openstackclient
    ```

## SQL
> コントローラノード
- パッケージのインストール
    ```
    $ apt install mariadb-server python3-pymysql
    ```
- 設定ファイル
    ```
    $ vim /etc/mysql/mariadb.conf.d/99-openstack.cnf
    ```
    ```
    [mysqld]
    bind-address = 10.0.0.10

    default-storage-engine = innodb
    innodb_file_per_table = on
    max_connections = 4096
    collation-server = utf8_general_ci
    character-set-server = utf8
    ```
    ```
    /etc/mysql/my.cnf
    [mysqld]
    bind-address = 10.0.0.10
    ```
- 最後に
    ```
    $ service mysql restart
    $ mysql_secure_installation
    ```

## RabbitMQ
> コントローラノード
- パッケージのインストール
    ```
    $ apt install rabbitmq-server
    ```
- ユーザの追加
    ```
    $ rabbitmqctl add_user openstack 0ta29SourC3
    ```
- 権限付与
    ```
    $ rabbitmqctl set_permissions openstack ".*" ".*" ".*"
    ```

## Memcached
> コントローラノード
- パッケージのインストール
    ```
    $ apt install memcached python3-memcache
    ```
- 設定ファイル
    ```
    $ vim /etc/memcached.conf
    ```
    ```
    -l 10.0.0.10
    ```
    > -l 127.0.0.1を置き換える
- 最後に
    ```
    $ service memcached restart
    ```
    
## Etcd
> コントローラノード
- パッケージのインストール
    ```
    $ apt install etcd
    ```
- 設定ファイル
    ```
    $ vim /etc/default/etcd
    ```
    ```
    ETCD_NAME="controller"
    ETCD_DATA_DIR="/var/lib/etcd"
    ETCD_INITIAL_CLUSTER_STATE="new"
    ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"
    ETCD_INITIAL_CLUSTER="controller=http://10.0.0.10:2380"
    ETCD_INITIAL_ADVERTISE_PEER_URLS="http://10.0.0.10:2380"
    ETCD_ADVERTISE_CLIENT_URLS="http://10.0.0.10:2379"
    ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
    ETCD_LISTEN_CLIENT_URLS="http://10.0.0.10:2379"
    ```
- 最後に
    ```
    $ systemctl enable etcd
    $ systemctl restart etcd
    ```

---
# 構築手順
- Victoriaを利用する

## Keystone
> コントローラノード
- DBの作成
    ```
    $ mysql
    ```
    ```
    MariaDB [(none)]> CREATE DATABASE keystone;
    ```
    ```
    MariaDB [(none)]> GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '0ta29SourC';
    MariaDB [(none)]> GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '0ta29SOurC3';
    MariaDB [(none)]> flush privileges; 
    MariaDB [(none)]> exit
    ```
- パッケージのインストール
    ```
    $ apt install keystone
    ```
- 設定ファイル
    ```
    $ vim /etc/keystone/keystone.conf
    ```
    ```
    [database]
    # ...
    connection = mysql+pymysql://keystone:0ta29SourC3@controller/keystone
    
    [token]
    # ...
    provider = fernet
    ```
- DBにデータを投入
    ```
    $ su -s /bin/sh -c "keystone-manage db_sync" keystone
    ```
- Fernet キー リポジトリを初期化
    ```
    $ keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
    $ keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
    ```
- ブートストラップ
    ```
    $ keystone-manage bootstrap --bootstrap-password 0ta29SourC3 \
      --bootstrap-admin-url http://controller:5000/v3/ \
      --bootstrap-internal-url http://controller:5000/v3/ \
      --bootstrap-public-url http://controller:5000/v3/ \
      --bootstrap-region-id RegionOne
    ```
- Apche
    ```
    $ vim /etc/apache2/apache2.conf
    ```
    ```
    ServerName controller
    ```
- 最後に
    ```
    $ service apache2 restart
    ```
    ```
    $ export OS_USERNAME=admin
    $ export OS_PASSWORD=0ta29SourC3
    $ export OS_PROJECT_NAME=admin
    $ export OS_USER_DOMAIN_NAME=Default
    $ export OS_PROJECT_DOMAIN_NAME=Default
    $ export OS_AUTH_URL=http://controller:5000/v3
    $ export OS_IDENTITY_API_VERSION=3
    ```
- ドメイン、プロジェクト、ユーザー、およびロールを作成
    ```
    $ openstack domain create --description "An Example Domain" example
    ```
    ```
    $ openstack project create --domain default \
      --description "Service Project" service
    ```
    - 特権のないプロジェクトとユーザの追加 (myproject & myuser)
        ```
        $ openstack project create --domain default \
          --description "Demo Project" myproject
        ```
        ```
        $ openstack user create --domain default \
          --password-prompt myuser
        ```
        ```
        $ openstack role create myrole
        ```
        ```
        $ openstack role add --project myproject --user myuser myrole
        ```
- 動作確認
    ```
    $ unset OS_AUTH_URL OS_PASSWORD
    ```
    > admin 認証トークン要求
    ```
    openstack --os-auth-url http://controller:5000/v3 \
      --os-project-domain-name Default --os-user-domain-name Default \
      --os-project-name admin --os-username admin token issue
    ```
    > myuser 認証トークン要求
    ```
    openstack --os-auth-url http://controller:5000/v3 \
      --os-project-domain-name Default --os-user-domain-name Default \
      --os-project-name myproject --os-username myuser token issue
    ```
- スクリプトの作成・使用
    ```
    $ cd
    $ vim admin-openrc
    ```
    ```
    export OS_PROJECT_DOMAIN_NAME=Default
    export OS_USER_DOMAIN_NAME=Default
    export OS_PROJECT_NAME=admin
    export OS_USERNAME=admin
    export OS_PASSWORD=0ta29SourC3
    export OS_AUTH_URL=http://controller:5000/v3
    export OS_IDENTITY_API_VERSION=3
    export OS_IMAGE_API_VERSION=2
    ```
    ```
    $ vim demo-openrc
    ```
    ```
    export OS_PROJECT_DOMAIN_NAME=Default
    export OS_USER_DOMAIN_NAME=Default
    export OS_PROJECT_NAME=myproject
    export OS_USERNAME=myuser
    export OS_PASSWORD=0ta29SOurC3
    export OS_AUTH_URL=http://controller:5000/v3
    export OS_IDENTITY_API_VERSION=3
    export OS_IMAGE_API_VERSION=2
    ```
    
    ```
    $ . admin-openrc
    $ openstack token issue
    ```

## Glance
> コントローラノード
- DBの作成
    ```
    $ mysql
    ```
    ```
    MariaDB [(none)]> CREATE DATABASE glance;
    ```
    ```
    MariaDB [(none)]> GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '0ta29SourC3';
    MariaDB [(none)]> GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '0ta29SourC3';
    MariaDB [(none)]> flush privileges; 
    MariaDB [(none)]> exit
    ```
- サービス資格情報、APIエンドポイントを作成
    > admin管理者専用の CLI コマンドにアクセスするための資格情報を入手
    ```
    $ . admin-openrc
    ```
    - サービス資格情報を作成
        ```
        $ openstack user create --domain default --password-prompt glance
        ```
        ```
        $ openstack role add --project service --user glance admin
        ```
        ```
        $ openstack service create --name glance --description "OpenStack Image" image
        ```
    ```
    $ openstack endpoint create --region RegionOne image public http://controller:9292
    $ openstack endpoint create --region RegionOne image internal http://controller:9292
    $ openstack endpoint create --region RegionOne image admin http://controller:9292
    ```
- パッケージのインストール
    ```
    $ apt install glance
    ```
- 設定ファイル
    ```
    $ vim /etc/glance/glance-api.conf
    ```
    ```
    [database]
    # ...
    connection = mysql+pymysql://glance:0ta29SourC3@controller/glance
    
    [keystone_authtoken]
    # ...
    www_authenticate_uri = http://controller:5000
    auth_url = http://controller:5000
    memcached_servers = controller:11211
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = service
    username = glance
    password = 0ta29SourC3

    [paste_deploy]
    # ...
    flavor = keystone
    
    [glance_store]
    # ...
    stores = file,http
    default_store = file
    filesystem_store_datadir = /var/lib/glance/images/
    ```
- DBにデータを投入
    ```
    $ su -s /bin/sh -c "glance-manage db_sync" glance
    ```
- 最後に
    ```
    $ service glance-api restart
    ```
- 動作確認 (コンテナでやるつもりなのでこの段階ではまだやらなくていい)
    ```
    $ . admin-openrc
    $ wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
    ```
    ```
    $ glance image-create --name "cirros" \
      --file cirros-0.4.0-x86_64-disk.img \
      --disk-format qcow2 --container-format bare \
      --visibility=public
    ```
    ```
    $ glance image-list
    ```

## Placement
> コントローラノード
> Novaの途中でインストールする順番でもOK
- DBの作成
    ```
    $ mysql
    ```
    ```
    MariaDB [(none)]> CREATE DATABASE placement;
    ```
    ```
    MariaDB [(none)]> GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY '0ta29SOurC3';
    MariaDB [(none)]> GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY '0ta29SourC3';
    MariaDB [(none)]> flush privileges; 
    MariaDB [(none)]> exit
    ```
- ユーザーとエンドポイント
    ```
    $ . admin-openrc
    ```
    ```
    $ openstack user create --domain default --password-prompt placement
    ```
    ```
    $ openstack role add --project service --user placement admin
    ```
    ```
    $ openstack service create --name placement --description "Placement API" placement
    ```
    ```
    $　openstack endpoint create --region RegionOne placement public http://controller:8778
    $ openstack endpoint create --region RegionOne placement internal http://controller:8778
    $ openstack endpoint create --region RegionOne placement admin http://controller:8778
    ```
- パッケージのインストール
    ```
    $ apt install placement-api
    ```
- 設定ファイル
    ```
    $ vim /etc/placement/placement.conf
    ```
    ```
    [placement_database]
    # ...
    connection = mysql+pymysql://placement:0ta29SourC3@controller/placement
    
    [api]
    # ...
    auth_strategy = keystone

    [keystone_authtoken]
    # ...
    auth_url = http://controller:5000/v3
    memcached_servers = controller:11211
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = service
    username = placement
    password = 0ta29SourC3
    ```
- DBにデータを投入
    ```
    $ su -s /bin/sh -c "placement-manage db sync" placement
    ```
- 最後に
    ```
    $ service apache2 restart
    ```
- 動作確認
    ```
    $ . admin-openrc
    ```
    ```
    $ placement-status upgrade check
    ```
    > 以下はやってなかった
    > 試してみないとわからない
    ```
    $ pip3 install osc-placement
    $ openstack --os-placement-api-version 1.2 resource class list --sort-column name
    $ openstack --os-placement-api-version 1.6 trait list --sort-column name
    ```
    > 「Nova から Placement へのアップグレード」はまだよくわかってない

## Nova
> コントローラノード
- DBの作成
    ```
    $ mysql
    ```
    ```
    MariaDB [(none)]> CREATE DATABASE nova_api;
    MariaDB [(none)]> CREATE DATABASE nova;
    MariaDB [(none)]> CREATE DATABASE nova_cell0;
    ```
    ```
    MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '0ta29SourC3';
    MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '0ta29SourC3';

    MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '0ta29SourC3';
    MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '0ta29SourC3';

    MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '0ta29SourC3';
    MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '0ta29SourC3';
    ```
- サービス資格情報、APIエンドポイントを作成
    ```
    $ . admin-openrc
    ```
    - サービスの資格情報を作成
        ```
        $ openstack user create --domain default --password-prompt nova
        ```
        ```
        $ openstack role add --project service --user nova admin
        ```
        ```
        $ openstack service create --name nova --description "OpenStack Compute" compute
        ```
    ```
    $ openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1
    $ openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1
    $ openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1
    ```
    > ここでPlacementインストールしてもOK
- パッケージのインストール
    ```
    $ apt install nova-api nova-conductor nova-novncproxy nova-scheduler
    ```
    ```
    $ vim /etc/nova/nova.conf
    ```
    ```
    [api_database]
    # ...
    connection = mysql+pymysql://nova:0ta29SourC3@controller/nova_api

    [database]
    # ...
    connection = mysql+pymysql://nova:0ta29SourC3@controller/nova
    
    [DEFAULT]
    # ...
    transport_url = rabbit://openstack:0ta29SourC3@controller:5672/
    
    [api]
    # ...
    auth_strategy = keystone

    [keystone_authtoken]
    # ...
    www_authenticate_uri = http://controller:5000/
    auth_url = http://controller:5000/
    memcached_servers = controller:11211
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = service
    username = nova
    password = 0ta29SOurC3
    
    [DEFAULT]
    # ...
    my_ip = 10.0.0.11
    
    > ここで[neutron]セクションを構成する
    > これはNeutronのインストール手順で行うため一旦スルー
    
    [vnc]
    enabled = true
    # ...
    server_listen = $my_ip
    server_proxyclient_address = $my_ip
    
    [glance]
    # ...
    api_servers = http://controller:9292
    
    [oslo_concurrency]
    # ...
    lock_path = /var/lib/nova/tmp
    
    [placement]
    # ...
    region_name = RegionOne
    project_domain_name = Default
    project_name = service
    auth_type = password
    user_domain_name = Default
    auth_url = http://controller:5000/v3
    username = placement
    password = 0ta29SourC3
    
    > パッケージ作成のバグがあるため、 [DEFAULT] セクションから log_dir オプションを削除します。
    ```
- DBにデータを投入
    ```
    $ su -s /bin/sh -c "nova-manage api_db sync" nova
    $ su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
    $ su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
    $ su -s /bin/sh -c "nova-manage db sync" nova
    ```
    ```
    $ su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova
    ```
- 最後に
    ```
    $ service nova-api restart
    $ service nova-scheduler restart
    $ service nova-conductor restart
    $ service nova-novncproxy restart
    ```
> コンピュートノード
- パッケージのインストール
    ```
    $ apt install nova-compute
    ```
- 設定ファイル
    ```
    $ vim etc/nova/nova.conf
    ```
    ```
    [DEFAULT]
    # ...
    transport_url = rabbit://openstack:0ta29SourC3@controller
    
    [api]
    # ...
    auth_strategy = keystone

    [keystone_authtoken]
    # ...
    www_authenticate_uri = http://controller:5000/
    auth_url = http://controller:5000/
    memcached_servers = controller:11211
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = service
    username = nova
    password = 0ta29SourC3
    
    [DEFAULT]
    # ...
    my_ip = 10.0.0.20
    
    > ここで[neutron]セクションを構成する
    > これはNeutronのインストール手順で行うため一旦スルー
    
    [vnc]
    # ...
    enabled = true
    server_listen = 0.0.0.0
    server_proxyclient_address = $my_ip
    novncproxy_base_url = http://controller:6080/vnc_auto.html
    
    [glance]
    # ...
    api_servers = http://controller:9292
    
    [oslo_concurrency]
    # ...
    lock_path = /var/lib/nova/tmp

    [placement]
    # ...
    region_name = RegionOne
    project_domain_name = Default
    project_name = service
    auth_type = password
    user_domain_name = Default
    auth_url = http://controller:5000/v3
    username = placement
    password = 0ta29SourC3
    ```
- 最後に
    - ハードウェアアクセラレーションに対応しているか確認
        ```
        $ egrep -c '(vmx|svm)' /proc/cpuinfo
        ```
        > zeroじゃなければOK
    ```
    $ service nova-compute restart
    ```
    
> コントローラノード
- DBへの投入
    ```
    $ . admin-openrc
    $ openstack compute service list --service nova-compute
    ```
    ```
    $ su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
    ```
- 動作確認
    ```
    $ . admin-openrc
    $ openstack compute service list
    ```
    ```
    $ openstack catalog list
    $ openstack image list
    $ nova-status upgrade check
    ```

## Neutron
> コントローラノード
- DBの作成
    ```
    $ mysql
    ```
    ```
    MariaDB [(none)] CREATE DATABASE neutron;
    MariaDB [(none)]> GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '0ta29SourC3';
    MariaDB [(none)]> GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '0ta29SOurC3';
    ```
- サービス資格情報、APIエンドポイントを作成
    ```
    $ . admin-openrc
    ```
    - サービスの資格情報を作成
        ```
        $ openstack user create --domain default --password-prompt neutron
        ```
        ```
        $ openstack role add --project service --user neutron admin
        ```
        ```
        openstack service create --name neutron --description "OpenStack Networking" network
        ```
    ```
    $ openstack endpoint create --region RegionOne network public http://controller:9696
    $ openstack endpoint create --region RegionOne network internal http://controller:9696
    $ openstack endpoint create --region RegionOne network admin http://controller:9696
    ```
- ネットワークオプションの設定
    - オプション1: プロバイダーネットワーク
        - 今回は省略
    - オプション2: セルフサービスネットワーク
        - [セルフサービスネットワークの構築](https://docs.openstack.org/neutron/victoria/install/controller-install-option2-ubuntu.html)
- **Self-service Networking**
    > コントローラノード
    - コンポーネントのインストール
        ```
        $ apt install neutron-server neutron-plugin-ml2 \
          neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent \
          neutron-metadata-agent
        ```
    - 設定ファイル
        ```
        $ vim /etc/neutron/neutron.conf
        ```
        ```
        [DEFAULT]
        # ...
        core_plugin = ml2
        service_plugins = router
        allow_overlapping_ips = true
        
        [DEFAULT]
        # ...
        transport_url = rabbit://openstack:0ta29SourC3@controller
        
        [DEFAULT]
        # ...
        auth_strategy = keystone

        [keystone_authtoken]
        # ...
        www_authenticate_uri = http://controller:5000
        auth_url = http://controller:5000
        memcached_servers = controller:11211
        auth_type = password
        project_domain_name = default
        user_domain_name = default
        project_name = service
        username = neutron
        password = 0ta29SourC3
        
        [DEFAULT]
        # ...
        notify_nova_on_port_status_changes = true
        notify_nova_on_port_data_changes = true

        [nova]
        # ...
        auth_url = http://controller:5000
        auth_type = password
        project_domain_name = default
        user_domain_name = default
        region_name = RegionOne
        project_name = service
        username = nova
        password = 0ta29SourC3
        ```
    - ML2プラグイン構成
        ```
        $ vim /etc/neutron/plugins/ml2/ml2_conf.ini
        ```
        ```
        [ml2]
        # ...
        type_drivers = flat,vlan,vxlan
        
        [ml2]
        # ...
        tenant_network_types = vxlan
        
        [ml2]
        # ...
        mechanism_drivers = linuxbridge,l2population
        
        [ml2]
        # ...
        extension_drivers = port_security

        [ml2_type_flat]
        # ...
        flat_networks = provider
        
        [ml2_type_vxlan]
        # ...
        vni_ranges = 1:1000
        
        [securitygroup]
        # ...
        enable_ipset = true
        ```
    - Linux Bridgeエージェントの構成
        ```
        $ vim /etc/neutron/plugins/ml2/linuxbridge_agent.ini
        ```
        ```
        > enp1s0: プロバイダーの物理ネットワークインターフェイスの名前に置き換える
        [linux_bridge]
        physical_interface_mappings = provider:enp1s0
        
        > オーバーレイ ネットワークを処理する基盤となる物理ネットワークインターフェイスの IP アドレスに置き換える
        > サンプル アーキテクチャでは、管理インターフェイスを使用してトラフィックを他のノードにトンネリングする
        > そのため、コントローラーノードの管理 IP アドレスに置き換える
        [vxlan]
        enable_vxlan = true
        local_ip = 10.0.0.10
        l2_population = true
        
        [securitygroup]
        # ...
        enable_security_group = true
        firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
        ```
        ```
        net.bridge.bridge-nf-call-iptables
        net.bridge.bridge-nf-call-ip6tables
        ```
        > 1ならOK
    - L3エージェントの構成
        ```
        $ vim /etc/neutron/l3_agent.ini
        ```
        ```
        [DEFAULT]
        # ...
        interface_driver = linuxbridge
        ```
    - DHCPエージェントの設定
        ```
        $ vim /etc/neutron/dhcp_agent.ini
        ```
        ```
        [DEFAULT]
        # ...
        interface_driver = linuxbridge
        dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
        enable_isolated_metadata = true
        ```
- [ここ](https://docs.openstack.org/neutron/victoria/install/controller-install-obs.html#neutron-controller-metadata-agent-obs)に戻る
> コントローラノード
- メタデータエージェントの構成
    ```
    $ vim /etc/neutron/metadata_agent.ini
    ```
    ```
    [DEFAULT]
    # ...
    nova_metadata_host = controller
    metadata_proxy_shared_secret = 0ta29SOurC3
    ```
- nova構成
    ```
    $ vim /etc/nova/nova.conf
    ```
    ```
    [neutron]
    # ...
    auth_url = http://controller:5000
    auth_type = password
    project_domain_name = default
    user_domain_name = default
    region_name = RegionOne
    project_name = service
    username = neutron
    password = 0ta29SOurC3
    service_metadata_proxy = true
    metadata_proxy_shared_secret = 0ta29SourC3
    ```
- 最後に
    ```
    $ systemctl restart openstack-nova-api.service
    ```
    ```
    $ systemctl enable openstack-neutron.service \
      openstack-neutron-linuxbridge-agent.service \
      openstack-neutron-dhcp-agent.service \
      openstack-neutron-metadata-agent.service
    $ systemctl start openstack-neutron.service \
      openstack-neutron-linuxbridge-agent.service \
      openstack-neutron-dhcp-agent.service \
      openstack-neutron-metadata-agent.service
    ```
    ```
    $ systemctl enable openstack-neutron-l3-agent.service
    $ systemctl start openstack-neutron-l3-agent.service
    ```
    > 日本語版で構築したら少し違ったservice名になってるっぽい
    ```
    # service nova-api restart
    # service neutron-server restart
    # service neutron-linuxbridge-agent restart
    # service neutron-dhcp-agent restart
    # service neutron-metadata-agent restart
    # service neutron-l3-agent restart
    ```

> コンピュートノード
- コンポーネントのインストール
    ```
    $ apt install neutron-linuxbridge-agent
    ```
- 設定ファイル
    ```
    $ vim /etc/neutron/neutron.conf
    ```
    ```
    [DEFAULT]
    # ...
    transport_url = rabbit://openstack:0ta29SourC3@controller
    
    [DEFAULT]
    # ...
    auth_strategy = keystone

    [keystone_authtoken]
    # ...
    www_authenticate_uri = http://controller:5000
    auth_url = http://controller:5000
    memcached_servers = controller:11211
    auth_type = password
    project_domain_name = default
    user_domain_name = default
    project_name = service
    username = neutron
    password = 0ta29SourC3
    
    [oslo_concurrency]
    # ...
    lock_path = /var/lib/neutron/tmp
    ```
- ネットワークオプションの設定
    - オプション1: プロバイダーネットワーク
        - 今回は省略
    - オプション2: セルフサービスネットワーク
        - [セルフサービスネットワークの構築](https://docs.openstack.org/neutron/victoria/install/compute-install-option2-ubuntu.html)
- **Self-service Networking**
    > コンピュートノード
    - Linix Bridgeエージェントの構成
        ```
        $ vim /etc/neutron/plugins/ml2/linuxbridge_agent.ini
        ```
        ```
        > enp1s0: プロバイダーの物理ネットワークインターフェイスの名前に置き換える
        [linux_bridge]
        physical_interface_mappings = provider:enp1s0
        
        > オーバーレイ ネットワークを処理する基盤となる物理ネットワークインターフェイスの IP アドレスに置き換える
        > サンプル アーキテクチャでは、管理インターフェイスを使用してトラフィックを他のノードにトンネリングする
        > そのため、コンピュートノードの管理 IP アドレスに置き換える
        [vxlan]
        enable_vxlan = true
        local_ip = 10.0.0.20
        l2_population = true
        
        [securitygroup]
        # ...
        enable_security_group = true
        firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
        ```
        ```
        net.bridge.bridge-nf-call-iptables
        net.bridge.bridge-nf-call-ip6tables
        ```
        > 1ならOK
- [ここ](https://docs.openstack.org/neutron/victoria/install/compute-install-ubuntu.html#neutron-compute-compute-ubuntu)に戻る
> コンピュートノード
- nova構成
    ```
    $ vim /etc/nova/nova.conf
    ```
    ```
    [neutron]
    # ...
    auth_url = http://controller:5000
    auth_type = password
    project_domain_name = default
    user_domain_name = default
    region_name = RegionOne
    project_name = service
    username = neutron
    password = 0ta29SOurC3
    ```
- 最後に
    ```
    $ service nova-compute restart
    $ service neutron-linuxbridge-agent restart
    ```
- 動作確認
    > コントローラノード
    ```
    openstack network agent list
    ```


### OVNインストール
- [参考](https://docs.openstack.org/neutron/victoria/install/)
- [参考](https://docs.openstack.org/neutron/victoria/install/ovn/manual_install.html)





## [Zun](https://docs.openstack.org/zun/latest/install/index.html)
> コントローラノード
- DBの作成
    ```
    $ mysql
    ```
    ```
    $ MariaDB [(none)] CREATE DATABASE zun;
    ```
    ```
    $ MariaDB [(none)]> GRANT ALL PRIVILEGES ON zun.* TO 'zun'@'localhost' IDENTIFIED BY '0ta29SourC3';
    $ MariaDB [(none)]> GRANT ALL PRIVILEGES ON zun.* TO 'zun'@'%' IDENTIFIED BY '0ta29SourC3';
    ```
- サービス資格情報、APIエンドポイントを作成
    ```
    $ . admin-openrc
    ```
    - サービスの資格情報を作成
        ```
        $ openstack user create --domain default --password-prompt zun
        ```
        ```
        $ openstack role add --project service --user zun admin
        ```
        ```
        $ openstack service create --name zun --description "Container Service" container
        ```
    ```
    $ openstack endpoint create --region RegionOne container public http://controller:9517/v1
    $ openstack endpoint create --region RegionOne container internal http://controller:9517/v1
    $ openstack endpoint create --region RegionOne container admin http://controller:9517/v1
    ```
- コンポーネントのインストールと構成
- ユーザ作成・ディレクトリ作成
    ```
    $ groupadd --system zun
    $ useradd --home-dir "/var/lib/zun" \
          --create-home \
          --system \
          --shell /bin/false \
          -g zun \
          zun
    ```
    ```
    $ mkdir -p /etc/zun
    $ chown zun:zun /etc/zun
    ```
- 依存関係をインストール
    ```
    $ apt-get install python3-pip git
    ```
- zunのクローン
    ```
    $ cd /var/lib/zun
    $ git clone https://opendev.org/openstack/zun.git
    // git clone -b stable/victoria https://opendev.org/openstack/zun/src/branch/stable/victoria
    // もしくは、git checkout stable/victoria
    $ chown -R zun:zun zun
    $ cd zun
    $ pip3 install -r requirements.txt
    $ python3 setup.py install
    ```
    > root~ errorの解決方法:
    > git config --global --add safe.directory /var/lib/zun/zun
- サンプル構成ファイルを生成
    ```
    $ su -s /bin/sh -c "oslo-config-generator --config-file etc/zun/zun-config-generator.conf" zun
    $ su -s /bin/sh -c "cp etc/zun/zun.conf.sample /etc/zun/zun.conf" zun
    ```
- api-paste.iniをコピー
    ```
    $ su -s /bin/sh -c "cp etc/zun/api-paste.ini /etc/zun" zun
    ```
- 設定ファイル
    ```
    $ vim /etc/zun/zun.conf
    ```
    ```
    [DEFAULT]
    ...
    transport_url = rabbit://openstack:0ta29SourC3@controller
    
    [api]
    ...
    host_ip = 10.0.0.10
    port = 9517
    
    [database]
    ...
    connection = mysql+pymysql://zun:0ta29SourC3@controller/zun
    
    [keystone_auth]
    memcached_servers = controller:11211
    www_authenticate_uri = http://controller:5000
    project_domain_name = default
    project_name = service
    user_domain_name = default
    password = 0ta29SourC3
    username = zun
    auth_url = http://controller:5000
    auth_type = password
    auth_version = v3
    auth_protocol = http
    service_token_roles_required = True
    endpoint_type = internalURL

    [keystone_authtoken]
    ...
    memcached_servers = controller:11211
    www_authenticate_uri = http://controller:5000
    project_domain_name = default
    project_name = service
    user_domain_name = default
    password = 0ta29SourC3
    username = zun
    auth_url = http://controller:5000
    auth_type = password
    auth_version = v3
    auth_protocol = http
    service_token_roles_required = True
    endpoint_type = internalURL
    
    [oslo_concurrency]
    ...
    lock_path = /var/lib/zun/tmp
    
    [oslo_messaging_notifications]
    ...
    driver = messaging
    
    [websocket_proxy]
    ...
    wsproxy_host = 10.0.0.10
    wsproxy_port = 6784
    base_url = ws://controller:6784/
    ```
- Zun データベースにデータを入力
    ```
    $ su -s /bin/sh -c "zun-db-manage upgrade" zun
    ```
- 最後に
    ```
    $ vim /etc/systemd/system/zun-api.service
    ```
    ```
    [Unit]
    Description = OpenStack Container Service API

    [Service]
    ExecStart = /usr/local/bin/zun-api
    User = zun

    [Install]
    WantedBy = multi-user.target
    ```
    ```
    $ vim /etc/systemd/system/zun-wsproxy.service
    ```
    ```
    [Unit]
    Description = OpenStack Container Service Websocket Proxy

    [Service]
    ExecStart = /usr/local/bin/zun-wsproxy
    User = zun

    [Install]
    WantedBy = multi-user.target
    ```
    ```
    $ systemctl enable zun-api
    $ systemctl enable zun-wsproxy
    $ systemctl start zun-api
    $ systemctl start zun-wsproxy
    $ systemctl status zun-api
    $ systemctl status zun-wsproxy
    ```

> コンピュートノード
- 事前準備
    - Zun をインストールして構成する前に、Docker と Kuryr-libnetwork を計算ノードに正しくインストールし、Etcd をコントローラー ノードに正しくインストールする必要があります。
    - **Docker**
        ```
        $ apt install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg-agent \
            software-properties-common
        ```
        ```
        $ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        ```
        ```
        $ apt-key fingerprint 0EBFCD88
        ```
        ```
        $ add-apt-repository \
            "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) \
            stable"
        ```
        ```
        $ apt update
        $ apt-get install -y docker-ce docker-ce-cli containerd.io
        ```
        ```
        $ systemctl restart docker
        ```
    - **Kuryr-libnetwork**
        ```
        $ . admin-openrc
        ```
        ```
        $ openstack user create --domain default --password-prompt kuryr
        ```
        ```
        $ openstack role add --project service --user kuryr admin
        ```
        - Docker が既にインストールされていることを前提
        - コンポーネントのインストールと構成 (Kuryr-libnetwork)
            ```
            $ groupadd --system kuryr
            $ useradd --home-dir "/var/lib/kuryr" \
                  --create-home \
                  --system \
                  --shell /bin/false \
                  -g kuryr \
                  kuryr
            ```
            ```
            $ mkdir -p /etc/kuryr
            $ chown kuryr:kuryr /etc/kuryr
            ```
            ```
            $ apt-get install python3-pip
            $ cd /var/lib/kuryr
            $ git clone -b master https://opendev.org/openstack/kuryr-libnetwork.git
            $ chown -R kuryr:kuryr kuryr-libnetwork
            $ cd kuryr-libnetwork
            $ pip3 install -r requirements.txt
            $ python3 setup.py install
            ```
            ```
            $ su -s /bin/sh -c "./tools/generate_config_file_samples.sh" kuryr
            $ su -s /bin/sh -c "cp etc/kuryr.conf.sample /etc/kuryr/kuryr.conf" kuryr
            ```
            ```
            $ vim /etc/kuryr/kuryr.conf
            ```
            ```
            [DEFAULT]
            ...
            bindir = /usr/local/libexec/kuryr
            
            [neutron]
            ...
            www_authenticate_uri = http://controller:5000
            auth_url = http://controller:5000
            username = kuryr
            user_domain_name = default
            password = 0ta29SourC3
            project_name = service
            project_domain_name = default
            auth_type = password
            ```
            ```
            $ vim /etc/systemd/system/kuryr-libnetwork.service
            ```
            ```
            [Unit]
            Description = Kuryr-libnetwork - Docker network plugin for Neutron

            [Service]
            ExecStart = /usr/local/bin/kuryr-server --config-file /etc/kuryr/kuryr.conf
            CapabilityBoundingSet = CAP_NET_ADMIN
            AmbientCapabilities = CAP_NET_ADMIN

            [Install]
            WantedBy = multi-user.target
            ```
            ```
            $ systemctl enable kuryr-libnetwork
            $ systemctl start kuryr-libnetwork
            $ systemctl restart docker
            ```

- コンポーネントのインストールと構成 (zun)
- ユーザ作成・ディレクトリ作成
    ```
    $ groupadd --system zun
    $ useradd --home-dir "/var/lib/zun" \
          --create-home \
          --system \
          --shell /bin/false \
          -g zun \
          zun
    ```
    ```
    $ mkdir -p /etc/zun
    $ chown zun:zun /etc/zun
    ```
    ```
    $ mkdir -p /etc/cni/net.d
    $ chown zun:zun /etc/cni/net.d
    ```
- 依存関係をインストール
    ```
    $ apt-get install python3-pip git numactl
    ```
- zunのクローン
    ```
    $ cd /var/lib/zun
    $ git clone https://opendev.org/openstack/zun.git
    $ chown -R zun:zun zun
    $ cd zun
    $ pip3 install -r requirements.txt
    $ python3 setup.py install
    ```
- サンプル構成ファイルを生成
    ```
    $ su -s /bin/sh -c "oslo-config-generator --config-file etc/zun/zun-config-generator.conf" zun
    $ su -s /bin/sh -c "cp etc/zun/zun.conf.sample /etc/zun/zun.conf" zun
    $ su -s /bin/sh -c "cp etc/zun/rootwrap.conf /etc/zun/rootwrap.conf" zun
    $ su -s /bin/sh -c "mkdir -p /etc/zun/rootwrap.d" zun
    $ su -s /bin/sh -c "cp etc/zun/rootwrap.d/* /etc/zun/rootwrap.d/" zun
    $ su -s /bin/sh -c "cp etc/cni/net.d/* /etc/cni/net.d/" zun
    ```
- zunユーザーの sudoers
    ```
    $ echo "zun ALL=(root) NOPASSWD: /usr/local/bin/zun-rootwrap /etc/zun/rootwrap.conf *" | sudo tee /etc/sudoers.d/zun-rootwrap
    ```
- 設定ファイル
    ```
    $ vim /etc/zun/zun.conf
    ```
    ```
    [DEFAULT]
    ...
    transport_url = rabbit://openstack:0ta29SourC3@controller
    
    [DEFAULT]
    ...
    state_path = /var/lib/zun
    
    [database]
    ...
    connection = mysql+pymysql://zun:0ta29SourC3@controller/zun
    
    [keystone_auth]
    memcached_servers = controller:11211
    www_authenticate_uri = http://controller:5000
    project_domain_name = default
    project_name = service
    user_domain_name = default
    password = 0ta29SourC3
    username = zun
    auth_url = http://controller:5000
    auth_type = password
    auth_version = v3
    auth_protocol = http
    service_token_roles_required = True
    endpoint_type = internalURL
    
    [keystone_authtoken]
    ...
    memcached_servers = controller:11211
    www_authenticate_uri= http://controller:5000
    project_domain_name = default
    project_name = service
    user_domain_name = default
    password = 0ta29SourC3
    username = zun
    auth_url = http://controller:5000
    auth_type = password
    
    [oslo_concurrency]
    ...
    lock_path = /var/lib/zun/tmp
    
    [compute]
    ...
    host_shared_with_nova = true
    ```
    > 権限の再設定: "$ chown zun:zun /etc/zun/zun.conf"
- Docker と Kuryr を構成
    - ディレクトリ作成・docker設定ファイル
        ```
        $ mkdir -p /etc/systemd/system/docker.service.d
        ```
        ```
        $ vim /etc/systemd/system/docker.service.d/docker.conf
        ```
        ```
        [Service]
        ExecStart=
        ExecStart=/usr/bin/dockerd --group zun -H tcp://compute10:2375 -H unix:///var/run/docker.sock --cluster-store etcd://controller:2379
        ```
    - docker 再起動
        ```
        $ systemctl daemon-reload
        $ systemctl restart docker
        ```
    - Kuryr 設定ファイル
        ```
        $ vim /etc/kuryr/kuryr.conf
        ```
        ```
        [DEFAULT]
        ...
        capability_scope = global
        process_external_connectivity = False
        ```
    - Kuryr-libnetwork 再起動
        ```
        $ systemctl restart kuryr-libnetwork
        ```
- コンテナを構成
    ```
    $ containerd config default > /etc/containerd/config.toml
    ```
    ```
    $ vim /etc/containerd/config.toml
    ```
    ```
    $ [grpc]
        ...
        gid = ZUN_GROUP_ID
    ```
    > ZUN_GROUP_ID は以下の結果に置き換える
    ```
    $ getent group zun | cut -d: -f3
    ```
    > 権限の再設定: "chown zun:zun /etc/containerd/config.toml"
    ```
    $ systemctl restart containerd
    ```
- CNI を構成
    ```
    $ mkdir -p /opt/cni/bin
    $ curl -L https://github.com/containernetworking/plugins/releases/download/v0.7.1/cni-plugins-amd64-v0.7.1.tgz \
          | tar -C /opt/cni/bin -xzvf - ./loopback
    ```
    ```
    $ install -o zun -m 0555 -D /usr/local/bin/zun-cni /opt/cni/bin/zun-cni
    ```
- 最後に
    ```
    $ vim /etc/systemd/system/zun-compute.service
    ```
    ```
    [Unit]
    Description = OpenStack Container Service Compute Agent

    [Service]
    ExecStart = /usr/local/bin/zun-compute
    User = zun

    [Install]
    WantedBy = multi-user.target
    ```
    ```
    $ vim /etc/systemd/system/zun-cni-daemon.service
    ```
    ```
    [Unit]
    Description = OpenStack Container Service CNI daemon

    [Service]
    ExecStart = /usr/local/bin/zun-cni-daemon
    User = zun

    [Install]
    WantedBy = multi-user.target
    ```
    ```
    # systemctl enable zun-compute
    # systemctl start zun-compute
    # systemctl enable zun-cni-daemon
    # systemctl start zun-cni-daemon
    # systemctl status zun-compute
    # systemctl status zun-cni-daemon
    ```
- 動作確認
    > コントローラノード
    ```
    $ pip3 install python-zunclient
    ```
    ```
    $ . admin-openrc
    ```
    ```
    $ openstack appcontainer service list
    ```
    > 前はここでstateがupにならない不具合があった

## [インスタンスの起動](https://docs.openstack.org/ocata/ja/install-guide-ubuntu/launch-instance.html)
- 仮想ネットワークの作成
    - **プロバイダーネットワーク**
        ```
        $ . admin-openrc
        ```
        ```
        $ openstack network create  --share --external \
          --provider-physical-network provider \
          --provider-network-type flat provider
        ```
        > --externalオプションは、仮想ネットワークを外部として定義します。
        > 内部ネットワークを作成したい場合は、--internal代わりに使用できます。デフォルト値はinternalです。
        
        > --provider-physical-network provider と --provider-network-type flat オプションにより、以下の行にある情報を使用して、仮想フラットネットワークを、ホストの eth1 インターフェースのフラット (ネイティブ、タグなし) プロバイダー物理ネットワークに接続します。

        - ml2_conf.ini:
        ```
        [ml2_type_flat]
        flat_networks = provider
        ```
        - linuxbridge_agent.ini:
        ```
        [linux_bridge]
        physical_interface_mappings = provider:eth1
        ```
        
        ```
        $ openstack subnet create --network provider \
          --allocation-pool start=165.242.125.245,end=165.242.125.254 \
          --dns-nameserver 165.242.125.40 --gateway 165.242.125.1 \
          --subnet-range 165.242.125.0/24 provider
        ```
    - **セルフサービスネットワーク**
        > ↓ ネットワークの作成
        ```
        $ . demo-openrc
        ```
        ```
        $ openstack network create selfservice
        ```
        > 非特権ユーザーは、一般的にこのコマンドに追加パラメーターを指定できません。サービスは、以下のファイルの情報を使用して、自動的にパラメーターを選択します。
        - ml2_conf.ini:
        ```
        [ml2]
        tenant_network_types = vxlan

        [ml2_type_vxlan]
        vni_ranges = 1:1000
        ```
        > 169.~とかにした方がいいかも(Distcloud的に)
        ```
        $ openstack subnet create --network selfservice \
          --dns-nameserver 8.8.4.4 --gateway 172.16.1.1 \
          --subnet-range 172.16.1.0/24 selfservice
        ```
        > ↓ ルータの作成
        ```
        $ . admin-openrc
        $ . demo-openrc
        ```
        ```
        $ openstack router create router
        $ neutron router-interface-add router selfservice
        $ neutron router-gateway-set router provider
        ```
        - 動作検証
        ```
        $ . admin-openrc
        $ ip netns
        $ neutron router-port-list router
        // ここのIPはルーターのポートを一覧表示して、プロバイダーネットワークのゲートウェイ IP アドレスを指定
        $ ping -c 4 203.0.113.102
        ```
- [参考](https://docs.openstack.org/ocata/ja/install-guide-ubuntu/launch-instance.html)
        
- コンテナを起動
    > コントローラ
    ```
    $ . demo-openrc
    ```
    ```
    $ openstack network list
    ```
    ```
    $ export NET_ID=$(openstack network list | awk '/ selfservice / { print $2 }')
    ```
    ```
    $ openstack appcontainer run --name container --net network=$NET_ID cirros ping 8.8.8.8
    ```
    ```
    $ openstack appcontainer list
    ```
    ```
    $ openstack appcontainer exec --interactive container /bin/s
    # ping ~~~
    ```
    ```
    $ openstack appcontainer stop container
    $ openstack appcontainer delete container
    ```

- コンテナイメージの登録方法
    - hogehoge














---
# Tips
- トラシューなどで使えそうな内容をメモ
    - 作成したユーザを使ってパスワード認証でアクセスできるか
    ```
    $ mysql -u keystone -h 10.0.0.10 -p
    ```
    - Portが空いてるか (コンピュートノードからコントローラノードに対して実行)
    ```
    $ nmap -p 3306 10.0.0.10
    ```
    - どのPortで待ち受けしてるか
    ```
    $ netstat -tnlp
    ```

- Endpoint Sample
    ![](./img/wAXfjFl.jpg)
    
    

