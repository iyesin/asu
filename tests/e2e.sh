#!/usr/bin/env bash

set -Ee -o pipefail -o functrace

builder="http://127.0.0.1:18000"
reply="$(mktemp)"
save_loc="${HOME}/tmp/"
version="22.03.5"
target="x86/64"
profile="openwrt-x86-64-generic"
diff_pkgs="true"

clean_up(){
  local lineno=$1
  shift
  local msg="$*"
  echo "Got error on line ${lineno}: '${msg}'"
  rm -vrf "$reply"
}

trap 'clean_up $LINENO "$BASH_COMMAND"' ERR EXIT

gen_package_list() {
  sed_common='s/([[:space:]]*,)+/,/g; s/[[:space:]]+/ /g; s/^[[:space:]]+//'
  jq_transform='split("[[:space:]]*,[[:space:]]*"; "is") | flatten(3)'
  PKGLIST="
    amd64-microcode, flashrom, irqbalance, fstrim,
    base-files, busybox, dnsmasq-full, dropbear, e2fsprogs,
    ip6tables-mod-nat, ipset, iw-full, gpioctl-sysfs,
    cryptsetup, kmod-leds-gpio, kmod-crypto-hw-ccp, kmod-gpio-nct5104d,
    kmod-crypto-aead, kmod-crypto-acompress, kmod-crypto-cbc, kmod-crypto-ccm,
    kmod-crypto-chacha20poly1305, kmod-crypto-cmac, kmod-crypto-crc32,
    kmod-crypto-crc32c, kmod-crypto-ctr, kmod-crypto-cts, kmod-crypto-deflate,
    kmod-crypto-ecb, kmod-crypto-ecdh, kmod-crypto-echainiv,
    kmod-crypto-fcrypt, kmod-crypto-gcm, kmod-crypto-gf128, kmod-crypto-ghash,
    kmod-crypto-hmac, kmod-crypto-kpp, kmod-crypto-lib-chacha20poly1305,
    kmod-crypto-lib-curve25519, kmod-crypto-rng, kmod-crypto-rsa,
    kmod-crypto-seqiv, kmod-crypto-sha1, kmod-crypto-sha256,
    kmod-crypto-sha512, kmod-crypto-user, kmod-crypto-xcbc, kmod-crypto-xts,
    kmod-cryptodev, kmod-dm-raid, kmod-gpio-button-hotplug, kmod-kvm-amd,
    kmod-sp5100-tco, kmod-usb2, kmod-usb3, kmod-sound-core, kmod-pcspkr,
    kmod-fs-btrfs, kmod-fs-cifs, kmod-fs-configfs, kmod-fs-efivarfs,
    kmod-fs-exfat, kmod-fs-ext4, kmod-fs-f2fs, kmod-fs-fscache, kmod-fs-isofs,
    kmod-fs-jfs, kmod-fs-ntfs, kmod-fs-squashfs, kmod-fs-udf, kmod-fs-vfat,
    kmod-fs-xfs, kmod-fuse, kmod-wireguard, kmod-zram, kmod-ata-ahci,
    kmod-nf-conntrack, kmod-nf-conntrack-netlink, kmod-nf-conntrack6,
    kmod-nf-flow, kmod-nf-ipt, kmod-nf-ipt6, kmod-nf-ipvs,kmod-nf-log,
    kmod-nf-log6, kmod-nf-nat, kmod-nf-nat6, kmod-nf-nathelper,
    kmod-nf-nathelper-extra, kmod-nf-reject, kmod-nf-reject6, kmod-nfnetlink,
    kmod-nfnetlink-log, kmod-nfnetlink-queue,
    kmod-nft-bridge, kmod-nft-compat, kmod-nft-fib,
    kmod-nft-nat, kmod-nft-netdev, kmod-nft-offload, kmod-nft-queue,
    kmod-nft-socket, kmod-nft-tproxy, kmod-amd-xgbe, kmod-bnx2, kmod-e1000e,
    kmod-e1000, kmod-forcedeth, kmod-igb, kmod-igc, kmod-ixgbe, kmod-r8169
    kmod-crypto-manager, kmod-crypto-rng, kmod-cryptodev, kmod-fs-exfat,
    kmod-fs-squashfs, kmod-fs-vfat, kmod-gpio-button-hotplug, kmod-gre,
    kmod-ip6tables, kmod-ipt-ipopt, kmod-ipt-nat6,
    kmod-ipt-offload, kmod-ipt-raw, kmod-ipt-raw6, kmod-leds-gpio,
    kmod-mmc,
    kmod-nat46, kmod-nft-offload, kmod-nft-nat, kmod-nls-utf8, kmod-random-core,
    kmod-tcp-bbr, kmod-tun, kmod-usb3, kmod-usb-acm,
    kmod-usb-net-cdc-ether, kmod-usb-ledtrig-usbport,
    qemu-arm-softmmu, qemu-bridge-helper, qemu-firmware-pxe,
    qemu-firmware-seabios, qemu-firmware-seavgabios, qemu-x86_64-softmmu,
    luci-app-dockerman, luci-app-openvpn, luci-app-wireguard,
    openvpn-openssl, kmod-wireguard,
    luci-app-shadowsocks-libev, shadowsocks-libev-config,
    shadowsocks-libev-ss-tunnel, shadowsocks-libev-ss-server,
    shadowsocks-libev-ss-rules, v2raya, v2ray-extra,
    socat, openssh-client-utils, ksmbd-utils,
    luci-app-ksmbd, nginx-mod-luci, lvm2,
    logd, lsblk, luci, luci-app-acme, luci-app-commands, luci-app-firewall,
    luci-app-opkg, luci-app-unbound, luci-app-upnp, luci-mod-admin-full,
    luci-proto-bonding, luci-proto-ipip, luci-proto-ipv6, luci-proto-ppp,
    luci-ssl-openssl,
    macchanger, mount-utils, mtd, netifd, odhcp6c, odhcpd-ipv6only,
    openwrt-keyring, ppp, ppp-mod-pppoe, procd, ppp-mod-pptp, ppp-mod-pppol2tp,
    prometheus-node-exporter-lua-nat_traffic,
    prometheus-node-exporter-lua-openwrt, prometheus-node-exporter-lua-wifi,
    prometheus-node-exporter-lua-wifi_stations,
    resolveip, rsync, ubi-utils, ubox, ucert, uci, uclient-fetch,
    unbound-anchor, unbound-checkconf, unbound-control, unbound-control-setup,
    unbound-host,
    urandom-seed, urngd, usign, wireless-regdb, wpad-openssl"
  tr -d "\n" <<<"${PKGLIST}" | sed -Ee "${sed_common}" | jq -rR "$jq_transform"
}



fetch_build_manifest() {
  local yafs_site="$1"

  curl \
    -X POST \
    -H 'Accept: */*' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H "Referer: ${yafs_site}/" \
    -H "Origin: ${yafs_site}" \
    -H 'Content-Type: application/json' \
    --data-raw '
  {
  "rootfs_size_mb_max": "900",
  "defaults": "",
  "diff_packages": '"${diff_pkgs}"',
  "version": "'"${version}"'",
  "target": "'"${target}"'",
  "profile": "'"${profile}"'",
  "packages": '"$(gen_package_list)"'
  }' \
    "${yafs_site}/api/v1/build"
}

get_sha256_name(){
  rfile="$1"
  2>/dev/null jq --raw-output --exit-status '.images[] | .sha256 + "  " + .name' "$rfile"
}

we_have_it(){
  download_dir="$1"
  reply_file="$2"

  s2_name="$(get_sha256_name "$reply_file")"
  cd "$download_dir"
  echo "$s2_name" | 2>/dev/null sha256sum --check --status -
}

is_ready(){
  reply_file="$1"

  get_sha256_name "$reply_file" | grep -qE '[^[:space:]]+'
}

gen_names(){
  reply="$1"
  2>/dev/null jq --raw-output '"store/" + .bin_dir + "/" + .images[].name' "$reply"
}

fetch_build_blob(){
  prefix="$1"
  reply_file="$2"
  download_dir="$3"

  names=($(gen_names "$reply_file"))
  for path in ${names[*]}; do
    filename=${path##*/}
    full_path="$prefix/$path"
    save_to="$download_dir/$filename"
    curl -o "$save_to" "$full_path"
  done
}

fetch_build_manifest "$builder" >"$reply"
while ! is_ready "$reply"; do
  2>/dev/null jq . "$reply" && sleep 10 || sleep 5
  fetch_build_manifest "$builder" >"$reply"
done

if ! we_have_it "$save_loc" "$reply"; then
  fetch_build_blob "$builder" "$reply" "$save_loc"
fi
