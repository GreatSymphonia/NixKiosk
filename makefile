# Makefile for building and flashing the NixOS kiosk image

build:
	nix build .#iso --extra-experimental-features "nix-command flakes"
	sh -c 'for f in result/iso/*.iso; do [ -e "$$f" ] || break; cp -fL "$$f" ./nixos-kiosk-lanets.iso && chmod 0644 ./nixos-kiosk-lanets.iso && chown $(shell id -u):$(shell id -g) ./nixos-kiosk-lanets.iso 2>/dev/null || true; break; done'

flash:
	sudo dd if=./nixos-kiosk-lanets.iso of=/dev/sda bs=4M status=progress conv=fsync

clean:
	rm -rf result
	rm -f ./nixos-kiosk-lanets.iso
