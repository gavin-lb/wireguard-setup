#!/usr/bin/env bash
set -e

WG_IF="wg0"
WG_PORT="51820"
WG_NET="10.0.0.0/24"
WG_SERVER_IP="10.0.0.1/24"
WG_CLIENT_IP="10.0.0.2/32"
WG_DIR="/etc/wireguard"

echo "Updating system..."
apt update
apt upgrade -y

echo "Installing packages..."
apt install -y wireguard nftables qrencode unattended-upgrades

echo "Enabling automatic security updates..."
/usr/sbin/dpkg-reconfigure -f noninteractive unattended-upgrades

echo "Detecting public network interface..."
PUBLIC_IF=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
echo "Detected interface: $PUBLIC_IF"

echo "Enabling IPv4 forwarding..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
sysctl --system

echo "Creating WireGuard directory..."
mkdir -p $WG_DIR
chmod 700 $WG_DIR

echo "Generating server keys..."
wg genkey | tee $WG_DIR/server_private.key | wg pubkey > $WG_DIR/server_public.key
chmod 600 $WG_DIR/server_private.key

SERVER_PRIVATE=$(cat $WG_DIR/server_private.key)
SERVER_PUBLIC=$(cat $WG_DIR/server_public.key)

echo "Generating client keys..."
wg genkey | tee $WG_DIR/client_private.key | wg pubkey > $WG_DIR/client_public.key
CLIENT_PRIVATE=$(cat $WG_DIR/client_private.key)
CLIENT_PUBLIC=$(cat $WG_DIR/client_public.key)

echo "Creating WireGuard config..."

cat > $WG_DIR/$WG_IF.conf <<EOF
[Interface]
Address = $WG_SERVER_IP
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE

[Peer]
PublicKey = $CLIENT_PUBLIC
AllowedIPs = $WG_CLIENT_IP
EOF

chmod 600 $WG_DIR/$WG_IF.conf

echo "Configuring nftables firewall..."

cat > /etc/nftables.conf <<EOF
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0;
        policy drop;

        ct state established,related accept
        iif "lo" accept

        tcp dport 22 accept
        udp dport $WG_PORT accept
    }

    chain forward {
        type filter hook forward priority 0;
        policy drop;

        iifname "$WG_IF" accept
        oifname "$WG_IF" accept
    }
}

table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100;

        oif "$PUBLIC_IF" masquerade
    }
}
EOF

echo "Starting WireGuard..."
systemctl enable wg-quick@$WG_IF
wg-quick up $WG_IF

echo "Enabling nftables..."
systemctl enable nftables
systemctl restart nftables

SERVER_IP=$(curl -s ifconfig.me)

CLIENT_CONF="$WG_DIR/client.conf"

cat > $CLIENT_CONF <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE
Address = 10.0.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC
Endpoint = $SERVER_IP:$WG_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

chmod 600 $CLIENT_CONF

echo
echo "WireGuard setup complete."
echo
echo "===== QR CODE (for mobile clients) ====="
echo
qrencode -t ansiutf8 < $CLIENT_CONF

echo
echo "===== CLIENT CONFIG ====="
echo
cat $CLIENT_CONF