#!/bin/bash
#
clear
echo""
echo "# - Tor BRIDGE/PROXY script for Raspberry Pi Zero W and DietPi v9.0.2."
echo "# - Need dietpi default user exist."
echo "# - Compile tor and obfs4proxy from git and install without service."
echo "# - Generate Tor BRIDGE config with socks disable and monitor enable (nyx)."
echo "# - Generate Tor PROXY config with socks enable, hidden_service (ftp - ircd) enable and monitor enable (nyx)."
echo "# - Create scripts to start and stop it manually."
echo "# - If Tor BRIDGE is behind a FIREWALL or NAT, make sure to open or forward TCP port 9001 and 9002."
echo "# - If Tor PROXY is behind a FIREWALL make sure to open TCP port 9050."
echo "# - It will take about 3/4 hours to complete everything on Raspberry Pi Zero W."
ech""
echo "# - START TOR BRIDGE: /home/dietpi/tor/torstartb.sh"
echo "# - START TOR PROXY: /home/dietpi/tor/torstartp.sh"
echo "# - STOP TOR: /home/dietpi/tor/trostop.sh"
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
mkdir /home/dietpi/tor/hidden_service
mkdir /home/dietpi/tor/log
chmod 700 /home/dietpi/tor
chmod 700 /home/dietpi/tor/bin
chmod 700 /home/dietpi/tor/data
chmod 700 /home/dietpi/tor/etc
chmod 700 /home/dietpi/tor/hidden_service
chmod 700 /home/dietpi/tor/log
install -c -m 700 src/app/tor src/tools/tor-resolve src/tools/tor-print-ed-signing-cert src/tools/tor-gencert '/home/dietpi/tor/bin'
install -c -m 600 src/config/geoip src/config/geoip6 '/home/dietpi/tor/data'

echo "#Tor Bridge" > /home/dietpi/tor/torstartb.sh
sed -i '$ a su - dietpi -c "/home/dietpi/tor/bin/tor -f /home/dietpi/tor/etc/torrc.bridge"' /home/dietpi/tor/torstartb.sh
sed -i '$ a exit 0' /home/dietpi/tor/torstartb.sh
chmod 700 /home/dietpi/tor/torstartb.sh

echo "#Tor Proxy" > /home/dietpi/tor/torstartp.sh
sed -i '$ a su - dietpi -c "/home/dietpi/tor/bin/tor -f /home/dietpi/tor/etc/torrc.proxy"' /home/dietpi/tor/torstartp.sh
sed -i '$ a exit 0' /home/dietpi/tor/torstartp.sh
chmod 700 /home/dietpi/tor/torstartp.sh

echo "#Tor Stop" > /home/dietpi/tor/torstop.sh
sed -i '$ a pkill -e tor -9' /home/dietpi/tor/torstop.sh
sed -i '$ a exit 0' /home/dietpi/tor/torstop.sh
chmod 700 /home/dietpi/tor/torstop.sh

cd
curl -L https://go.dev/dl/go1.21.6.linux-armv6l.tar.gz | tar zxf -
curl -L https://gitlab.com/yawning/obfs4/-/archive/master/obfs4-master.tar.gz | tar zxf -
cd obfs4-master
../go/bin/go build -o obfs4proxy/obfs4proxy ./obfs4proxy
mv obfs4proxy/obfs4proxy /home/dietpi/tor/bin
setcap cap_net_bind_service=+ep /home/dietpi/tor/bin/obfs4proxy
rm -r ../.cache/go-build

echo "DataDirectory /home/dietpi/tor/data" > /home/dietpi/tor/etc/torrc.bridge
echo "GeoIPFile /home/dietpi/tor/data/geoip" >> /home/dietpi/tor/etc/torrc.bridge
echo "GeoIPv6File /home/dietpi/tor/data/geoip6" >> /home/dietpi/tor/etc/torrc.bridge
echo "Log notice file /home/dietpi/tor/log/notices.log" >> /home/dietpi/tor/etc/torrc.bridge
echo "SocksPort 0" >> /home/dietpi/tor/etc/torrc.bridge
echo "BridgeRelay 1" >> /home/dietpi/tor/etc/torrc.bridge
echo "RunAsDaemon 1" >> /home/dietpi/tor/etc/torrc.bridge
echo "AvoidDiskWrites 1" >> /home/dietpi/tor/etc/torrc.bridge
echo "ControlPort 9051" >> /home/dietpi/tor/etc/torrc.bridge
echo "CookieAuthentication 1" >> /home/dietpi/tor/etc/torrc.bridge
echo "CookieAuthFile /home/dietpi/tor/data/control_auth_cookie" >> /home/dietpi/tor/etc/torrc.bridge
echo "ControlSocket /home/dietpi/tor/data/control_socket" >> /home/dietpi/tor/etc/torrc.bridge
echo "Address $(curl icanhazip.com)" >> /home/dietpi/tor/etc/torrc.bridge
echo "ORPort 9001" >> /home/dietpi/tor/etc/torrc.bridge
echo "ServerTransportPlugin obfs4 exec /home/dietpi/tor/bin/obfs4proxy" >> /home/dietpi/tor/etc/torrc.bridge
echo "ServerTransportListenAddr obfs4 0.0.0.0:9002" >> /home/dietpi/tor/etc/torrc.bridge
echo "ExtORPort auto" >> /home/dietpi/tor/etc/torrc.bridge
echo "ContactInfo bridge@pizero.org" >> /home/dietpi/tor/etc/torrc.bridge
echo "Nickname BRiDGEPiZERO" >> /home/dietpi/tor/etc/torrc.bridge
echo "BandwidthRate 1024 KBytes" >> /home/dietpi/tor/etc/torrc.bridge
echo "BandwidthBurst 1536 KBytes" >> /home/dietpi/tor/etc/torrc.bridge
echo "MaxAdvertisedBandwidth 1280 KBytes" >> /home/dietpi/tor/etc/torrc.bridge
echo "PublishServerDescriptor bridge" >> /home/dietpi/tor/etc/torrc.bridge
echo "BridgeDistribution any" >> /home/dietpi/tor/etc/torrc.bridge

echo "SOCKSPort 9050" > /home/dietpi/tor/etc/torrc.proxy
echo "DataDirectory /home/dietpi/tor/data" >> /home/dietpi/tor/etc/torrc.proxy
echo "Log notice file /home/dietpi/tor/log/notices.log" >> /home/dietpi/tor/etc/torrc.proxy
echo "GeoIPFile /home/dietpi/tor/data/geoip" >> /home/dietpi/tor/etc/torrc.proxy
echo "GeoIPv6File /home/dietpi/tor/data/geoip6" >> /home/dietpi/tor/etc/torrc.proxy
echo "RunAsDaemon 1" >> /home/dietpi/tor/etc/torrc.proxy
echo "HiddenServiceDir /home/dietpi/tor/hidden_service/ftp" >> /home/dietpi/tor/etc/torrc.proxy
echo "HiddenServicePort 21 127.0.0.1:21" >> /home/dietpi/tor/etc/torrc.proxy
echo "HiddenServiceDir /home/dietpi/tor/hidden_service/ircd" >> /home/dietpi/tor/etc/torrc.proxy
echo "HiddenServicePort 6667 127.0.0.1:6667" >> /home/dietpi/tor/etc/torrc.proxy
echo "ControlPort 9051" >> /home/dietpi/tor/etc/torrc.proxy
echo "CookieAuthentication 1" >> /home/dietpi/tor/etc/torrc.proxy
echo "CookieAuthFile /home/dietpi/tor/data/control_auth_cookie" >> /home/dietpi/tor/etc/torrc.proxy
echo "ControlSocket /home/dietpi/tor/data/control_socket" >> /home/dietpi/tor/etc/torrc.proxy

chmod 600 /home/dietpi/tor/etc/torrc*
chown -R dietpi:dietpi /home/dietpi

exit 0
