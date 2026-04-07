# wireguard-setup
[![MIT license](https://img.shields.io/github/license/gavin-lb/wireguard-setup)](LICENSE)

A bash script for setting up a secure [WireGuard](https://www.wireguard.com/) VPN server installation on a freshly deployed Debian based system.

## Features

- Updates system and enables automatic security updates
- Installs and configures WireGuard
- Generates secure key for server & client
- Installs and configures nftables firewall for NAT + IP forwarding
- Provides client configuration in plaintext and QR code for mobile devices

## Usage

- Spin up a low-resource/free-tier VM at the desired endpoint location with your cloud provider of choice
- Ensure that the CSP firewall allows UDP port 51820
- SSH into the VM and execute the script
  ```bash
  sudo bash <(curl -s https://github.com/gavin-lb/wireguard-setup/setup.sh)
  ```
- Copy the output client config to your WireGuard client or scan the QR code with the WireGuard mobile app