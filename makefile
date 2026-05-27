# Makefile for building and flashing the NixOS kiosk image

build:
	nix build .#iso --extra-experimental-features "nix-command flakes"

flash:
	sudo dd if=result/iso/nixos-kiosk-lanets.iso of=/dev/sdX bs=4M status=progress conv=fsync

clean:
	rm -rf result
