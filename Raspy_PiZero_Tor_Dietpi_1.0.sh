#!/bin/bash
#
clear
echo""
echo "# - Install and configure a Tor BRIDGE for Raspberry Pi Zero W and DietPi v9.0.2."
echo "# - Need dietpi default user exist."
echo "# - Compile tor and obfs4proxy from git."
echo "# - Generate Tor BRIDGE config with socks disable and monitor enable (nyx)."
echo "# - If Tor BRIDGE is behind a FIREWALL or NAT, make sure to open or forward TCP port 9001 and 9002."
echo "# - It will take about 3/4 hours to complete everything on Raspberry Pi Zero W."
ech""
echo -n "Press <any_key> to continue or <ctrl+c> for terminate."
read randomkey

if [[ $EUID -ne 0 ]]; then
   echo "!!! This script must be run as root !!!" 
   exit 1
fi

apt update
apt install -y automake build-essential curl libevent-dev libssl-dev liblzma-dev libzstd-dev nyx pkg-config vnstat zlib1g-dev
curl -L https://dist.torproject.org/tor-0.4.8.10.tar.gz | tar zxf -
cd tor-0.4.8.10
./configure --disable-asciidoc
make

mkdir /home/dietpi/tor
mkdir /home/dietpi/tor/bin
mkdir /home/dietpi/tor/data
mkdir /home/dietpi/tor/etc
mkdir /home/dietpi/tor/log
chmod 700 /home/dietpi/tor
chmod 700 /home/dietpi/tor/bin
chmod 700 /home/dietpi/tor/data
chmod 700 /home/dietpi/tor/etc
chmod 700 /home/dietpi/tor/log
install -c -m 700 src/app/tor src/tools/tor-resolve src/tools/tor-print-ed-signing-cert src/tools/tor-gencert '/home/dietpi/tor/bin'
install -c -m 600 src/config/geoip src/config/geoip6 '/home/dietpi/tor/data'

echo "[Unit]" > /etc/systemd/system/tor.service
echo "Description=TOR Anonymizing Overlay Network" >> /etc/systemd/system/tor.service
echo "After=network.target" >> /etc/systemd/system/tor.service
echo "" >> /etc/systemd/system/tor.service
echo "[Service]" >> /etc/systemd/system/tor.service
echo "User=dietpi" >> /etc/systemd/system/tor.service
echo "Group=dietpi" >> /etc/systemd/system/tor.service
echo "" >> /etc/systemd/system/tor.service
echo "PrivateTmp=yes" >> /etc/systemd/system/tor.service
echo "" >> /etc/systemd/system/tor.service
echo "PermissionsStartOnly=true" >> /etc/systemd/system/tor.service
echo "" >> /etc/systemd/system/tor.service
echo "ExecStart=/home/dietpi/tor/bin/tor -f /home/dietpi/tor/etc/torrc" >> /etc/systemd/system/tor.service
echo "" >> /etc/systemd/system/tor.service
echo "ExecReload=/usr/bin/kill -HUP $MAINPID" >> /etc/systemd/system/tor.service
echo "" >> /etc/systemd/system/tor.service
echo "PIDFile=/home/dietpi/tor/tor.pid" >> /etc/systemd/system/tor.service
echo "KillSignal=SIGINT" >> /etc/systemd/system/tor.service
echo "LimitNOFILE=8192" >> /etc/systemd/system/tor.service
echo "PrivateDevices=yes" >> /etc/systemd/system/tor.service
echo "" >> /etc/systemd/system/tor.service
echo "[Install]" >> /etc/systemd/system/tor.service
echo "WantedBy=multi-user.target" >> /etc/systemd/system/tor.service

cd
curl -L https://go.dev/dl/go1.21.6.linux-armv6l.tar.gz | tar zxf -
curl -L https://gitlab.com/yawning/obfs4/-/archive/master/obfs4-master.tar.gz | tar zxf -
cd obfs4-master
../go/bin/go build -o obfs4proxy/obfs4proxy ./obfs4proxy
mv obfs4proxy/obfs4proxy /home/dietpi/tor/bin
setcap cap_net_bind_service=+ep /home/dietpi/tor/bin/obfs4proxy
rm -r ../.cache/go-build

echo "DataDirectory /home/dietpi/tor/data" > /home/dietpi/tor/etc/torrc
echo "GeoIPFile /home/dietpi/tor/data/geoip" >> /home/dietpi/tor/etc/torrc
echo "GeoIPv6File /home/dietpi/tor/data/geoip6" >> /home/dietpi/tor/etc/torrc
echo "Log notice file /home/dietpi/tor/log/notices.log" >> /home/dietpi/tor/etc/torrc
echo "PidFile /home/dietpi/tor/tor.pid" >> /home/dietpi/tor/etc/torrc
echo "SocksPort 0" >> /home/dietpi/tor/etc/torrc
echo "BridgeRelay 1" >> /home/dietpi/tor/etc/torrc
echo "RunAsDaemon 1" >> /home/dietpi/tor/etc/torrc
echo "AvoidDiskWrites 1" >> /home/dietpi/tor/etc/torrc
echo "ControlPort 9051" >> /home/dietpi/tor/etc/torrc
echo "CookieAuthentication 1" >> /home/dietpi/tor/etc/torrc
echo "CookieAuthFile /home/dietpi/tor/data/control_auth_cookie" >> /home/dietpi/tor/etc/torrc
echo "ControlSocket /home/dietpi/tor/data/control_socket" >> /home/dietpi/tor/etc/torrc
echo "Address $(curl icanhazip.com)" >> /home/dietpi/tor/etc/torrc
echo "ORPort 9001" >> /home/dietpi/tor/etc/torrc
echo "ServerTransportPlugin obfs4 exec /home/dietpi/tor/bin/obfs4proxy" >> /home/dietpi/tor/etc/torrc
echo "ServerTransportListenAddr obfs4 0.0.0.0:9002" >> /home/dietpi/tor/etc/torrc
echo "ExtORPort auto" >> /home/dietpi/tor/etc/torrc
echo "ContactInfo bridge@pizero.org" >> /home/dietpi/tor/etc/torrc
echo "Nickname BRiDGEPiZERO" >> /home/dietpi/tor/etc/torrc
echo "BandwidthRate 1024 KBytes" >> /home/dietpi/tor/etc/torrc
echo "BandwidthBurst 1536 KBytes" >> /home/dietpi/tor/etc/torrc
echo "MaxAdvertisedBandwidth 1280 KBytes" >> /home/dietpi/tor/etc/torrc
echo "PublishServerDescriptor bridge" >> /home/dietpi/tor/etc/torrc
echo "BridgeDistribution any" >> /home/dietpi/tor/etc/torrc

chmod 600 /home/dietpi/tor/etc/torrc
chown -R dietpi:dietpi /home/dietpi

systemctl daemon-reload
systemctl enable tor.service
systemctl start tor.service

exit 0
