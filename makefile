# Makefile for building and flashing the NixOS kiosk image

ISO := nixos-kiosk-lanets.iso
DEVICE ?= /dev/sda

build:
	nix build .#iso --extra-experimental-features "nix-command flakes"
	sh -c 'for f in result/iso/*.iso; do [ -e "$$f" ] || break; cp -fL "$$f" ./$(ISO) && chmod 0644 ./$(ISO) && chown $(shell id -u):$(shell id -g) ./$(ISO) 2>/dev/null || true; break; done'

flash:
	@echo "About to flash $(ISO) to $(DEVICE)"
	@echo "Press Ctrl+C within 5 seconds to abort..."
	@sleep 5
	sudo dd if=./$(ISO) of=$(DEVICE) bs=4M status=progress conv=fsync

clean:
	rm -rf result
	rm -f ./$(ISO)
