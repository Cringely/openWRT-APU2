echo ""
echo ""

echo ""
echo -e "\e[32m Board type            => `cat /sys/class/dmi/id/board_name` \e[0m"
echo -e "\e[32m Current BIOS version  => `cat /sys/class/dmi/id/bios_version` \e[0m"
#dmesg | grep -i apu


IS_APU2=`cat /sys/class/dmi/id/board_name | grep -i apu2 | wc -l`
IS_APU3=`cat /sys/class/dmi/id/board_name | grep -i apu3 | wc -l`
IS_APU4=`cat /sys/class/dmi/id/board_name | grep -i apu4 | wc -l`
IS_APU6=`cat /sys/class/dmi/id/board_name | grep -i apu6 | wc -l`

if [[ $IS_APU2 == "1" ]]
then
  BIOS_FILE='bios/apu2_v4.16.0.4.rom'
fi

if [[ $IS_APU3 == "1" ]]
then
  BIOS_FILE='bios/apu3_v4.16.0.4.rom'
fi

if [[ $IS_APU4 == "1" ]]
then
  BIOS_FILE='bios/apu4_v4.16.0.4.rom'
fi

if [[ $IS_APU6 == "1" ]]
then
  BIOS_FILE='bios/apu6_v4.16.0.4.rom'
fi

echo -e "\e[32m New BIOS file         => $BIOS_FILE "


if [[ $BIOS_FILE == "" ]]
then
  echo "Unknown board :-(. Exiting."
else
 echo -e "\e[32m Flashing.......\e[0m"
 echo ""
 echo ""
 flashrom -w $BIOS_FILE -p internal:boardmismatch=force
 echo ""
 echo ""
 echo -e "\e[32m Done. bip-bop.\e[0m"
fi

beep
