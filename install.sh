#!/bin/bash

download_stage3() {
  local MIRROR="https://ftp.belnet.be/pub/rsync.gentoo.org/gentoo"
  printf "\n"
  echo -e "\e[33m\xe2\x8f\xb3 Downloading the stage 3 tarball... \e[m"
  LATEST=$(wget --quiet $MIRROR/releases/amd64/autobuilds/latest-stage3-amd64.txt -O- | tail -n 1 | cut -d " " -f 1)
  echo $LATEST

  BASENAME=$(basename "$LATEST")
  wget -q --show-progress "$MIRROR/releases/amd64/autobuilds/$LATEST" 

}

