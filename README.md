# nixos bootstrap setup

## initial prep

setup wifi connection and enter root
```sh
nmcli device wifi connect SSID --ask
sudo -i
lsblk
```

## install using vm config
```sh
nix --extra-experimental-features 'nix-command flakes' \
  run github:jwdonovan/setup#install
```

## install using rog config
```sh
nix --extra-experimental-features 'nix-command flakes' \
  run github:jwdonovan/setup#install -- \
  --host rog \
  --disk /dev/nvme0n1
```
