#!/bin/bash
#
clear
echo""
echo "# - Install and configure a Tor BRIDGE for Raspberry Pi Zero W and Dietpi 9.0.2."
echo "# - Compile tor and obfs4proxy from source."
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

adduser --quiet --system --disabled-password --home /home/debian-tor --shell /bin/false --group debian-tor
mkdir /home/debian-tor/tor
mkdir /home/debian-tor/tor/bin
mkdir /home/debian-tor/tor/data
mkdir /home/debian-tor/tor/etc
mkdir /home/debian-tor/tor/log
chmod 770 /home/debian-tor/tor
chmod 770 /home/debian-tor/tor/bin
chmod 770 /home/debian-tor/tor/data
chmod 770 /home/debian-tor/tor/etc
chmod 770 /home/debian-tor/tor/log

apt update
apt install -y automake build-essential curl libevent-dev libssl-dev liblzma-dev libzstd-dev nyx pkg-config vnstat zlib1g-dev
curl -L https://dist.torproject.org/tor-0.4.8.10.tar.gz | tar zxf -
cd tor-0.4.8.10
./configure --disable-asciidoc
make
install -c -m 770 src/app/tor src/tools/tor-resolve src/tools/tor-print-ed-signing-cert src/tools/tor-gencert '/home/debian-tor/tor/bin'
install -c -m 660 src/config/geoip src/config/geoip6 '/home/debian-tor/tor/data'

cd
curl -L https://go.dev/dl/go1.21.6.linux-armv6l.tar.gz | tar zxf -
curl -L https://gitlab.com/yawning/obfs4/-/archive/master/obfs4-master.tar.gz | tar zxf -
cd obfs4-master
../go/bin/go build -o obfs4proxy/obfs4proxy ./obfs4proxy
mv obfs4proxy/obfs4proxy /home/debian-tor/tor/bin
setcap cap_net_bind_service=+ep /home/debian-tor/tor/bin/obfs4proxy
rm -r ../.cache/go-build

echo "[Unit]" > /etc/systemd/system/tor.service
echo "Description=TOR Anonymizing Overlay Network" >> /etc/systemd/system/tor.service
echo "After=network.target" >> /etc/systemd/system/tor.service
echo "" >> /etc/systemd/system/tor.service
echo "[Service]" >> /etc/systemd/system/tor.service
echo "User=debian-tor" >> /etc/systemd/system/tor.service
echo "Group=debian-tor" >> /etc/systemd/system/tor.service
echo "" >> /etc/systemd/system/tor.service
echo "PrivateTmp=yes" >> /etc/systemd/system/tor.service
echo "" >> /etc/systemd/system/tor.service
echo "PermissionsStartOnly=true" >> /etc/systemd/system/tor.service
echo "" >> /etc/systemd/system/tor.service
echo "ExecStart=/home/debian-tor/tor/bin/tor -f /home/debian-tor/tor/etc/torrc" >> /etc/systemd/system/tor.service
echo "" >> /etc/systemd/system/tor.service
echo "ExecReload=/usr/bin/kill -HUP $MAINPID" >> /etc/systemd/system/tor.service
echo "" >> /etc/systemd/system/tor.service
echo "PIDFile=/home/debian-tor/tor/tor.pid" >> /etc/systemd/system/tor.service
echo "KillSignal=SIGINT" >> /etc/systemd/system/tor.service
echo "LimitNOFILE=8192" >> /etc/systemd/system/tor.service
echo "PrivateDevices=yes" >> /etc/systemd/system/tor.service
echo "" >> /etc/systemd/system/tor.service
echo "[Install]" >> /etc/systemd/system/tor.service
echo "WantedBy=multi-user.target" >> /etc/systemd/system/tor.service

echo "DataDirectory /home/debian-tor/tor/data" > /home/debian-tor/tor/etc/torrc
echo "GeoIPFile /home/debian-tor/tor/data/geoip" >> /home/debian-tor/tor/etc/torrc
echo "GeoIPv6File /home/debian-tor/tor/data/geoip6" >> /home/debian-tor/tor/etc/torrc
echo "Log notice file /home/debian-tor/tor/log/notices.log" >> /home/debian-tor/tor/etc/torrc
echo "PidFile /home/debian-tor/tor/tor.pid" >> /home/debian-tor/tor/etc/torrc
echo "SocksPort 0" >> /home/debian-tor/tor/etc/torrc
echo "BridgeRelay 1" >> /home/debian-tor/tor/etc/torrc
echo "RunAsDaemon 1" >> /home/debian-tor/tor/etc/torrc
echo "AvoidDiskWrites 1" >> /home/debian-tor/tor/etc/torrc
echo "ControlPort 9051" >> /home/debian-tor/tor/etc/torrc
echo "CookieAuthentication 1" >> /home/debian-tor/tor/etc/torrc
echo "CookieAuthFile /home/debian-tor/tor/data/control_auth_cookie" >> /home/debian-tor/tor/etc/torrc
echo "ControlSocket /home/debian-tor/tor/data/control_socket" >> /home/debian-tor/tor/etc/torrc
echo "Address $(curl icanhazip.com)" >> /home/debian-tor/tor/etc/torrc
echo "ORPort 9001" >> /home/debian-tor/tor/etc/torrc
echo "ServerTransportPlugin obfs4 exec /home/debian-tor/tor/bin/obfs4proxy" >> /home/debian-tor/tor/etc/torrc
echo "ServerTransportListenAddr obfs4 0.0.0.0:9002" >> /home/debian-tor/tor/etc/torrc
echo "ExtORPort auto" >> /home/debian-tor/tor/etc/torrc
echo "ContactInfo bridge@pizero.org" >> /home/debian-tor/tor/etc/torrc
echo "Nickname BRiDGEPiZERO" >> /home/debian-tor/tor/etc/torrc
echo "BandwidthRate 1024 KBytes" >> /home/debian-tor/tor/etc/torrc
echo "BandwidthBurst 1536 KBytes" >> /home/debian-tor/tor/etc/torrc
echo "MaxAdvertisedBandwidth 1280 KBytes" >> /home/debian-tor/tor/etc/torrc
echo "PublishServerDescriptor bridge" >> /home/debian-tor/tor/etc/torrc
echo "BridgeDistribution any" >> /home/debian-tor/tor/etc/torrc

chmod 660 /home/debian-tor/tor/etc/torrc
usermod -a -G debian-tor dietpi
chown -R debian-tor:debian-tor /home/debian-tor

systemctl daemon-reload
systemctl enable tor.service
systemctl start tor.service
systemctl status tor.service

exit 0
