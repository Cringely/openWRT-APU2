#!/bin/bash -e

cd squash
rm filesystem.squashfs || :

mksquashfs squashfs-root filesystem.squashfs -b 1024k -e boot
cd ..
mv squash/filesystem.squashfs copied_iso_files/live/filesystem.squashfs

rm new_debian_live.iso || :

xorriso -outdev new_debian_live.iso -volid "APU OpenWRT autoflasher" -padding 0 -compliance no_emul_toc -map copied_iso_files / -chmod 0755 / -- -boot_image isolinux dir=/isolinux -boot_image isolinux system_area=isohdpfx.bin -boot_image any next -boot_image any efi_path=boot/grub/efi.img -boot_image isolinux partition_entry=gpt_basdat
beep;
