#! /bin/bash
clear

LANG=C

# build machine V 1.1
# build machine V 1.2 -> focused on auto build
# this one only for test build, Gabriel_Kernel_D855
# build dependencies
# libncurses5-dev build-essential zip git-core lib32stdc++6 lib32z1 lib32z1-dev
# TNX Dorimanx
# TNX Androplus
# -----------------------------------
# define variables

today=`date '+%Y_%m_%d__%H_%M_%S'`;
KD=$(readlink -f .);
TCA493=(TOOLCHAIN/architoolchain-4.9/bin/arm-architoolchain-linux-gnueabi-);
TCA510=(TOOLCHAIN/architoolchain-5.1/bin/arm-architoolchain-linux-gnueabihf-);
TCA520=(TOOLCHAIN/architoolchain-5.2/bin/arm-architoolchain-linux-gnueabihf-);
TCUB511=(TOOLCHAIN/UBERTC-5.1/bin/arm-eabi-);
TCUB520=(TOOLCHAIN/UBERTC-5.2/bin/arm-eabi-);
TCUB530=(TOOLCHAIN/UBERTC-5.3/bin/arm-eabi-);
TCUB600=(TOOLCHAIN/UBERTC-6.0/bin/arm-eabi-);
TCDR530=(TOOLCHAIN/TC-5.3-Dorimanx/bin/arm-eabi-);
TCLN494=(TOOLCHAIN/linaro-4.9.4-dorimanx/bin/arm-LG-linux-gnueabi-);
TS=(TOOLSET);
WD=(WORKING_DIR);
RK=(READY_KERNEL);
BOOT=(arch/arm/boot);
DTC=(scripts/dtc);
DCONF=(arch/arm/configs);
STOCK_DEF=(g3-global_com-perf_defconfig);

export PATH=$PATH:tools/lz4demo

CLEANUP()
{
	make clean mrproper && git clean -f;

### cleanup files creted previously

	for i in $(find "$KD"/ -name "*.ko"); do
		rm -fv "$i";
	done;
	for i in $(find "$KD"/ -name "boot.img"); do
		rm -fv "$i";
	done;
	for i in $(find "$KD"/ -name "dt.img"); do
		rm -fv "$i";
	done;
	for i in $(find "$KD"/ -name "*.zip" -not -path "*$RK/*"); do
		rm -fv "$i";
	done;
	for i in $(find "$KD"/ -name "zImage-dtb"); do
		rm -fv "$i";
	done;
	for i in $(find "$KD"/ -name "kernel_config_view_only"); do
		rm -fv "$i";
	done;
}

REBUILD()
{
NAME=Gabriel-$(grep "CONFIG_LOCALVERSION=" arch/arm/configs/gabriel_d855_* | cut -c 23-28);
FILENAME=($NAME-$(date +"[%d-%m]")-$MODEL);

ZIPFILE=$FILENAME
if [[ -e $RK/$ZIPFILE.zip ]] ; then
    i=0
    while [[ -e $RK/$ZIPFILE-$i.zip ]] ; do
        let i++
    done
    FILENAME=$ZIPFILE-$i
fi

clear
echo -e "\e[41mREBUILD\e[m"
sleep 3

	# Idea by savoca
	NR_CPUS=$(grep -c ^processor /proc/cpuinfo)

	if [ "$NR_CPUS" -le "2" ]; then
		NR_CPUS=4;
		echo "Building kernel with 4 CPU threads";
		echo ""
	else
		echo -e "\e[1;44mBuilding kernel with $NR_CPUS CPU threads\e[m"
		echo ""
	fi;

	echo "Start Build for" $MODEL > $WD/package/build_log;

	CLEANUP;
	time make ARCH=arm CROSS_COMPILE=$TC $CUSTOM_DEF
#	time make ARCH=arm CROSS_COMPILE=$TC nconfig
start=$(date +%s.%N)
	time make ARCH=arm CROSS_COMPILE=$TC zImage-dtb  -j ${NR_CPUS}
	time make ARCH=arm CROSS_COMPILE=$TC modules -j ${NR_CPUS}
clear

POST_BUILD;
}

CONTINUE_BUILD()
{
clear
echo -e "\e[41mCONTINUE_BUILD\e[m"
sleep 3
time make ARCH=arm CROSS_COMPILE=$TC zImage-dtb modules -j ${NR_CPUS}
clear

POST_BUILD;
}

POST_BUILD()
{
echo "checking for compiled kernel..."
if [ -f arch/arm/boot/zImage-dtb ]
then

echo "copy modules"
find . -name '*ko' -exec \cp '{}' $WD/package/system/lib/modules/ \;
chmod 755 $WD/package/system/lib/modules/*

	echo "Modules Copied" >> $WD/package/build_log;

# strip not needed debugs from modules.
"$TC"strip --strip-unneeded $WD/package/system/lib/modules/* 2>/dev/null
"$TC"strip --strip-debug $WD/package/system/lib/modules/* 2>/dev/null

	echo "Modules Striped" >> $WD/package/build_log;

echo "generating device tree..."
./dtbTool -o $BOOT/dt.img -s 2048 -p $DTC/ $BOOT/

	if [ -f $BOOT/dt.img ]; then
		echo -e "\e[42mdt.img PASSED\e[m"
		echo "Device Tree Builded" >> $WD/package/build_log;
	else
		echo -e "\e[41mdt.img FAILED\e[m"
		echo "Device Tree Failed" >> $WD/package/build_log;
	fi;

echo "copy zImage-dtb and dt.img"
\cp $BOOT/zImage-dtb $WD/$RAMDISK/
\cp $BOOT/dt.img $WD/$RAMDISK/

echo "creating boot.img"
./mkboot $WD/$RAMDISK $WD/boot.img

echo "bumping"
python open_bump.py $WD/boot.img

		echo "Bumped and Ready" >> $WD/package/build_log;

echo "copy bumped image"
\cp $WD/boot_bumped.img $WD/package/boot.img

echo "copy .config"
\cp .config $WD/package/kernel_config_view_only

echo "create flashable zip"
cd $WD/package
zip kernel.zip -r *

echo "copy flashable zip to output > flashable"
cd ..
cd ..
cp $WD/package/kernel.zip $RK/$FILENAME.zip
		
		#This part is for me on Workin Dir
		echo "Flashable ZIP is Ready" >> $WD/package/build_log;

clear
echo ""
echo -e "\e[1;44mWELL DONE ;)\e[m"
echo ""
echo ""
end=$(date +%s.%N)    
runtime=$(python -c "print(${end} - ${start})")
echo -e "\e[1;44mRuntime was $runtime\e[m"

		#This part is for me on Workin Dir
		echo $runtime >> $WD/package/build_log;

else
	echo -e "\e[1;31mKernel STUCK in BUILD! no zImage exist\e[m"

### THANKS GOD

fi
}

echo "Select Toolchain ... ";
select CHOICE in ARCHI-4.9.3 ARCHI-5.1.0 ARCHI-5.2.0 UBER-5.1.1 UBER-5.2.0 UBER-5.3.0 UBER-6.0.0 DORI-5.3.X LINARO-4.9.4 LAST_ONE CLEANUP CONTINUE_BUILD; do
	case "$CHOICE" in
		"ARCHI-4.9.3")
			TC=$TCA493;
			touch $WD/package/TOOLCHAIN_USED;
			echo archi-toolchain-4.9.3 > $WD/package/TOOLCHAIN_USED;
			break;;
		"ARCHI-5.1.0")
			TC=$TCA510;
			touch $WD/package/TOOLCHAIN_USED;
			echo archi-toolchain-5.1.0 > $WD/package/TOOLCHAIN_USED;
			break;;
		"ARCHI-5.2.0")
			TC=$TCA520;
			touch $WD/package/TOOLCHAIN_USED;
			echo archi-toolchain-5.2.0 > $WD/package/TOOLCHAIN_USED;
			break;;
		"UBER-5.1.1")
			TC=$TCUB511;
			touch $WD/package/TOOLCHAIN_USED;
			echo uber-toolchain-5.1.1 > $WD/package/TOOLCHAIN_USED;
			break;;
		"UBER-5.2.0")
			TC=$TCUB520;
			touch $WD/package/TOOLCHAIN_USED;
			echo uber-toolchain-5.2.0 > $WD/package/TOOLCHAIN_USED;
			break;;
		"UBER-5.3.0")
			TC=$TCUB530;
			touch $WD/package/TOOLCHAIN_USED;
			echo uber-toolchain-5.3.0 > $WD/package/TOOLCHAIN_USED;
			break;;
		"UBER-6.0.0")
			TC=$TCUB600;
			touch $WD/package/TOOLCHAIN_USED;
			echo uber-toolchain-6.0.0 > $WD/package/TOOLCHAIN_USED;
			break;;
		"DORI-5.3.X")
			TC=$TCDR530;
			touch $WD/package/TOOLCHAIN_USED;
			echo dorimanx-5.3.x > $WD/package/TOOLCHAIN_USED;
			break;;
		"LINARO-4.9.4")
			TC=$TCLN494;
			touch $WD/package/TOOLCHAIN_USED;
			echo linaro-toolchain-4.9.4 > $WD/package/TOOLCHAIN_USED;
			break;;
		"CONTINUE_BUILD")
			CONTINUE_BUILD;
			break;;
		"CLEANUP")
			CLEANUP;
			break;;
	esac;
done;
echo "What to do What not to do ?!";
select CHOICE in D850 D851 D852 D855 VS985 LS990 CONTINUE_BUILD D855_STOCK_DEF ALL; do
	case "$CHOICE" in
		"D850")
			CLEANUP;
			CUSTOM_DEF=gabriel_d850_defconfig
			MODEL=D850
			RAMDISK=D850
			REBUILD;
			break;;
		"D851")
			CLEANUP;
			CUSTOM_DEF=gabriel_d851_defconfig
			MODEL=D851
			RAMDISK=D851
			REBUILD;
			break;;
		"D852")
			CLEANUP;
			CUSTOM_DEF=gabriel_d852_defconfig
			MODEL=D852
			RAMDISK=D852
			REBUILD;
			break;;
		"D855")
			CLEANUP;
			CUSTOM_DEF=gabriel_d855_defconfig
			MODEL=D855
			RAMDISK=D855
			REBUILD;
			break;;
		"VS985")
			CLEANUP;
			CUSTOM_DEF=gabriel_vs985_defconfig
			MODEL=VS985
			RAMDISK=VS985
			REBUILD;
			break;;
		"LS990")
			CLEANUP;
			CUSTOM_DEF=gabriel_ls990_defconfig
			MODEL=LS990
			RAMDISK=LS990
			REBUILD;
			break;;
		"ALL")
			echo "starting build of D850 in 3"
			sleep 1;
			echo "starting build of D850 in 2"
			sleep 1;
			echo "starting build of D850 in 1"
			sleep 1;
			CLEANUP;
			CUSTOM_DEF=gabriel_d850_defconfig
			MODEL=D850
			RAMDISK=D850
			REBUILD;
			echo "D850 is ready!"
			echo "starting build of D851 in 3"
			sleep 1;
			echo "starting build of D851 in 2"
			sleep 1;
			echo "starting build of D851 in 1"
			sleep 1;
			CLEANUP;
			CUSTOM_DEF=gabriel_d851_defconfig
			MODEL=D851
			RAMDISK=D851
			REBUILD;
			echo "D851 is ready!"
			echo "starting build of D852 in 3"
			sleep 1;
			echo "starting build of D852 in 2"
			sleep 1;
			echo "starting build of D852 in 1"
			sleep 1;
			CLEANUP;
			CUSTOM_DEF=gabriel_d852_defconfig
			MODEL=D852
			RAMDISK=D852
			REBUILD;
			echo "D852 is ready!"
			echo "starting build of D855 in 3"
			sleep 1;
			echo "starting build of D855 in 2"
			sleep 1;
			echo "starting build of D855 in 1"
			sleep 1;
			CLEANUP;
			CUSTOM_DEF=gabriel_d855_defconfig
			MODEL=D855
			RAMDISK=D855
			REBUILD;
			echo "D855 is ready!"
			echo "starting build of VS985 in 3"
			sleep 1;
			echo "starting build of VS985 in 2"
			sleep 1;
			echo "starting build of VS985 in 1"
			sleep 1;
			CLEANUP;
			CUSTOM_DEF=gabriel_vs985_defconfig
			MODEL=VS985
			RAMDISK=VS985
			REBUILD;
			echo "VS985 is ready!"
			echo "starting build of LS990 in 3"
			sleep 1;
			echo "starting build of LS990 in 2"
			sleep 1;
			echo "starting build of LS990 in 1"
			sleep 1;
			CLEANUP;
			CUSTOM_DEF=gabriel_ls990_defconfig
			MODEL=LS990
			RAMDISK=LS990
			REBUILD;
			echo "LS990 is ready!"
			break;;
		"CONTINUE_BUILD")
			CONTINUE_BUILD;
			break;;
		"D855_STOCK_DEF")
			CUSTOM_DEF=$STOCK_DEF
			RAMDISK=D855
			REBUILD;
			break;;

	esac;
done;
