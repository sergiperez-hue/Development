#!/bin/bash

DISTROS=("Debian" "Ubuntu" "Mint" "Kali")
DISTROS+=("Arch")

echo "Primera distro: ${DISTROS[0]}"
echo "Total de distros: ${#DISTROS[@]}"
