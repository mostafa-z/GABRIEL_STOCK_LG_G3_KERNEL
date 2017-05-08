#! /bin/bash
clear

LANG=C

# build dependencies
# libncurses5-dev build-essential zip git-core lib32stdc++6 lib32z1 lib32z1-dev
# TNX Dorimanx, Androplus, Alucard_24, Andip71
# -----------------------------------
# folder structure
#------------------------------------
#	root (contains kernel source and these directories as well)
#		/TOOLCHAIN
#					/tc-name/bin/arm-eabi- or etc
#		/WORKING_DIR (available in mm_ramdisk git)
#					/D850/zImage.dtb,... (extracted from boot.img)
#					/D850/ramdisk
#					/D851/
#					/ ...
#					/ package (meta-inf,system,install.sh,... > kernel zip)
#					/ temp (empty)
#					/ ramdisk/ramdisk/ (res,sbin,tmp >> contains moded files)
#		/READY_KERNEL
#
# if anything goes wrong with permissions use fix-permissions.sh
# for TOOLCHAIN's permission denied use "sudo chmod -R 775 *" in its folder
#------------------------------------
# define variables
#------------------------------------
TODAY=`date '+%Y%m%d'`;
GIT_BRANCH=`git symbolic-ref --short HEAD`;
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[1;32m"
COLOR_NEUTRAL="\033[0m"
LOG=(WORKING_DIR/package/compile.log);
TCGAB=(TOOLCHAIN/gabriel-ctng/bin/arm-eabi-);
TCGL480=(TOOLCHAIN/google-4.8/bin/arm-eabi-);
TCA493=(TOOLCHAIN/architoolchain-4.9/bin/arm-architoolchain-linux-gnueabi-);
TCA510=(TOOLCHAIN/architoolchain-5.1/bin/arm-architoolchain-linux-gnueabihf-);
TCA520=(TOOLCHAIN/architoolchain-5.2/bin/arm-architoolchain-linux-gnueabihf-);
TCUB511=(TOOLCHAIN/UBERTC-5.1/bin/arm-eabi-);
TCUB520=(TOOLCHAIN/UBERTC-5.2/bin/arm-eabi-);
TCUB530=(TOOLCHAIN/UBERTC-5.3/bin/arm-eabi-);
TCUB600=(TOOLCHAIN/UBERTC-6.0/bin/arm-eabi-);
TCUB700=(TOOLCHAIN/UBERTC-7.0/bin/arm-eabi-);
TCDR530=(TOOLCHAIN/TC-5.3-Dorimanx/bin/arm-eabi-);
TCDR540=(TOOLCHAIN/TC-5.4-Dorimanx/bin/arm-eabi-);
TCDR610=(TOOLCHAIN/TC-6.1-Dorimanx/bin/arm-eabi-);
TCDR620=(TOOLCHAIN/TC-6.2-Dorimanx/bin/arm-eabi-);
TCLN494=(TOOLCHAIN/linaro-4.9.4-dorimanx/bin/arm-LG-linux-gnueabi-);
TCLN490=(TOOLCHAIN/linaro-4.9/bin/arm-eabi-);
TCLN530=(TOOLCHAIN/linaro-5.3/bin/arm-eabi-);
TCLN610=(TOOLCHAIN/linaro-6.1/bin/arm-eabi-);
TCLN630=(TOOLCHAIN/linaro-6.3/bin/arm-eabi-);
KD=$(readlink -f .);
WD=(WORKING_DIR);
RK=(READY_KERNEL);
BOOT=(arch/arm/boot);
DTC=(scripts/dtc);
DCONF=(arch/arm/configs);
STOCK_DEF=(g3-global_com-perf_defconfig);
NAME=Gabriel-$(grep "CONFIG_LOCALVERSION=" arch/arm/configs/gabriel_d855_defconfig | cut -c 23-28);

export PATH=$PATH:tools/lz4demo
#===============================================================================
# Define Functions
#===============================================================================

# to generate new file name if exist.(add a digit to new one)
FILENAME()
{
	ZIPFILE=$FILENAME
	if [[ -e $RK/$ZIPFILE.zip ]] ; then
    		i=0
    	while [[ -e $RK/$ZIPFILE-$i.zip ]] ; do
        	let i++
    	done
    FILENAME=$ZIPFILE-$i
	fi
}

# determine how many core your CPU have to build
NR_CPUS()
{
	# Idea by savoca
	NR_CPUS=$(grep -c ^processor /proc/cpuinfo)

	if [ "$NR_CPUS" -le "2" ]; then
		NR_CPUS=4;
		echo "Building kernel with 4 CPU threads";
	else
		echo -e "\e[1;44mBuilding kernel with $NR_CPUS CPU threads\e[m"
	fi;
}

# check if kernel zip file had build or not
FILE_CHECK()
{
	echo -e "\n***************************************************"
	echo -e "Check for coocked file:"
	if [ -f $RK/$FILENAME.zip ]; then
		echo -e $COLOR_GREEN
		echo "File name is: "$FILENAME".zip"
		echo -e $COLOR_NEUTRAL
	else
		echo -e $COLOR_RED
		echo "oops, &*%^&(%#!@#*(& !!"
		echo -e $COLOR_NEUTRAL		
	fi;
}

# check for errors
LOG_CHECK()
{
	echo -e "***************************************************"
	echo -e "Check for compile errors:"
	echo -e $COLOR_RED

	cd $WD/package
	grep error compile.log
	grep forbidden compile.log
	grep warning compile.log
	grep fail compile.log
	grep no compile.log
	echo -e $COLOR_NEUTRAL
# back to main directory
	cd ..
	cd ..

	echo -e "***************************************************"
}

# refresh for new build
CLEANUP()
{
	make ARCH=arm mrproper;
	make clean;

# force regeneration of .dtb and zImage files for every compile
	rm -f arch/arm/boot/*.dtb
	rm -f arch/arm/boot/*.cmd
	rm -f arch/arm/boot/zImage
	rm -f arch/arm/boot/Image

	if [ -d $WD/temp ]; then
		rm -rf $WD/temp/*
	else
		mkdir $WD/temp
	fi;

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
	for i in $(find "$KD"/ -name "compile.log"); do
		rm -fv "$i";
	done;
}

#===============================================================================
# Build Process
#===============================================================================

REBUILD()
{
clear
FILENAME=($NAME-$(date +"[%d-%m-%y]")-$MODEL);
FILENAME;
NR_CPUS;

	echo -e "\e[41mREBUILD\e[m"
	echo ""
	echo -e $COLOR_GREEN"Git Branch is at : "$GIT_BRANCH $COLOR_NEUTRAL
	echo ""
	sleep 3

	touch WORKING_DIR/package/compile.log
	echo -e "\n***************************************************" > $LOG
	echo -e "\nGIT branch and last commit : " >> $LOG
	git log --oneline --decorate -n 1 >> $LOG
	echo -e ""
	echo "CPU : compile with "$NR_CPUS"-way multitask processing" >> $LOG
	echo "Toolchain: "$TC >> $LOG

	TIMESTAMP1=$(date +%s)
	make ARCH=arm CROSS_COMPILE=$TC $CUSTOM_DEF
	echo -e $COLOR_GREEN"\nI'm coocking, make a coffee ..." $COLOR_NEUTRAL
	echo ""
	make ARCH=arm CROSS_COMPILE=$TC zImage-dtb -j $NR_CPUS | grep :
	make ARCH=arm CROSS_COMPILE=$TC modules -j $NR_CPUS | grep fail
	clear

POST_BUILD >> $LOG
FILE_CHECK;
LOG_CHECK;
}

REBUILD_NCONF()
{
clear
FILENAME=($NAME-$(date +"[%y-%m-%d]")-$MODEL);
FILENAME;
NR_CPUS;

	echo -e "\e[41mREBUILD\e[m"
	echo -e ""
	echo -e $COLOR_GREEN"Git Branch is at : "$GIT_BRANCH $COLOR_NEUTRAL
	echo -e ""
	sleep 3

	echo -e "\n***************************************************" > $LOG
	echo -e "\nGIT branch and last commit : " >> $LOG
	git log --oneline --decorate -n 1 >> $LOG
	echo -e ""
	echo -e "CPU : compile with "$NR_CPUS"-way multitask processing" >> $LOG
	echo -e "Toolchain: "$TC >> $LOG

	make ARCH=arm CROSS_COMPILE=$TC $CUSTOM_DEF
	make ARCH=arm CROSS_COMPILE=$TC nconfig
	echo -e $COLOR_GREEN"\nI'm coocking, make a coffee ..." $COLOR_NEUTRAL
	echo ""
	TIMESTAMP1=$(date +%s)
	make ARCH=arm CROSS_COMPILE=$TC zImage-dtb -j $NR_CPUS | grep :
	make ARCH=arm CROSS_COMPILE=$TC modules -j $NR_CPUS | grep fail
	clear

POST_BUILD >> $LOG
FILE_CHECK;
LOG_CHECK;
}

CONTINUE_BUILD()
{
	clear
	echo -e "\e[41mCONTINUE_BUILD\e[m"
	sleep 3
	time make ARCH=arm CROSS_COMPILE=$TC zImage-dtb -j ${CPUNUM}
	clear
}

POST_BUILD()
{
	echo -e "\nbuild for :" $MODEL
	echo -e "\nchecking for compiled kernel..."
	echo ""
if [ -f arch/arm/boot/zImage-dtb ]
	then

	if [ -d $WD/package/system/lib/modules ]; then
		rm -rf $WD/package/system/lib/modules/*
	else
		mkdir $WD/package/system/lib/modules
	fi;

	find . -name '*ko' -not -path "*TOOLCHAIN/*" -exec \cp '{}' $WD/package/system/lib/modules/ \;
	chmod 755 $WD/package/system/lib/modules/*
	echo "Modules has been copied" >> $LOG

# strip not needed debugs from modules.
	"$TC"strip --strip-unneeded $WD/package/system/lib/modules/* 2>/dev/null >> $LOG
	"$TC"strip --strip-debug $WD/package/system/lib/modules/* 2>/dev/null >> $LOG
	echo "Modules has been striped" >> $LOG

	echo "generating device tree..."
	echo ""
	./dtbTool -o $BOOT/dt.img -s 2048 -p $DTC/ $BOOT/ >> $LOG

	if [ -f $BOOT/dt.img ]; then
		echo -e "\nDevice Tree : Builded" >> $LOG
	else
		echo -e "\nDevice Tree : Failed !" >> $LOG
	fi;

	# copy all selected ramdisk files to temp folder
	\cp -r $WD/$RAMDISK/* $WD/temp
	\cp -r $WD/ramdisk/* $WD/temp
#	\cp -r $WD/anykernel/* $WD/temp

	echo "copy zImage-dtb and dt.img"
	echo ""
	\cp -v $BOOT/zImage-dtb $WD/temp/ >> $LOG
	\cp -v $BOOT/dt.img $WD/temp/ >> $LOG

	echo "creating boot.img"
	echo ""
	./mkboot $WD/temp $WD/boot.img >> $LOG

	echo -e "\nBumping"
	echo ""
	python open_bump.py $WD/boot.img >> $LOG

	echo "Bumped and Ready" >> $LOG

	echo "copy bumped image"
	\cp -v $WD/boot_bumped.img $WD/package/boot.img >> $LOG

	zImage=(stat -c%s $WD/temp/zImage-dtb);
	boot_img=(stat -c%s $WD/boot.img);
	echo ""
	echo "zImage size (bytes):"
	stat -c%s $WD/temp/zImage-dtb
	echo -n ""
	echo "boot.img size (bytes):"
	stat -c%s $WD/boot.img
	echo ""

	echo "copy .config"
	\cp -v .config $WD/package/kernel_config_view_only >> $LOG

	echo "Create flashable zip"
	cd $WD/package
	zip kernel.zip -r *

	echo "copy flashable zip to output > flashable"
	cd ..
	cd ..
	cp -v $WD/package/kernel.zip $RK/$FILENAME.zip
	md5sum $RK/$FILENAME.zip > $RK/$FILENAME.zip.md5
		
	#This part is for me on Workin Dir
	echo -e "\nFlashable zip is ready" >> $LOG

	TIMESTAMP2=$(date +%s) 
	TIME=$(($TIMESTAMP2 - $TIMESTAMP1))
	echo -e "\nCompile time: "$TIME "seconds" >> $LOG

else
	echo "Kernel STUCK in BUILD! no zImage exist !"

### THANKS GOD

fi;
}

echo "Select Toolchain ... ";
select CHOICE in Gabriel-ct.ng Google-4.8.0 ARCHI-4.9.3 ARCHI-5.1.0 ARCHI-5.2.0 UBER-5.1.1 UBER-5.2.0 UBER-5.3.0 UBER-6.0.0 UBER-7.0.0 DORI-LINARO-4.9.4 DORI-5.3.X DORI-5.4.X DORI-6.1.X DORI-6.2.X LINARO-4.9.x LINARO-5.3.x LINARO-6.1.x LINARO-6.3.x LAST_ONE CLEANUP CONTINUE_BUILD; do
	case "$CHOICE" in
		"Gabriel-ct.ng")
			TC=$TCGAB;
			break;;
		"Google-4.8.0")
			TC=$TCGL480;
			break;;
		"ARCHI-4.9.3")
			TC=$TCA493;
			break;;
		"ARCHI-5.1.0")
			TC=$TCA510;
			break;;
		"ARCHI-5.2.0")
			TC=$TCA520;
			break;;
		"UBER-5.1.1")
			TC=$TCUB511;
			break;;
		"UBER-5.2.0")
			TC=$TCUB520;
			break;;
		"UBER-5.3.0")
			TC=$TCUB530;
			break;;
		"UBER-6.0.0")
			TC=$TCUB600;
			break;;
		"UBER-7.0.0")
			TC=$TCUB700;
			break;;
		"DORI-LINARO-4.9.4")
			TC=$TCLN494;
			break;;
		"DORI-5.3.X")
			TC=$TCDR530;
			break;;
		"DORI-5.4.X")
			TC=$TCDR540;
			break;;
		"DORI-6.1.X")
			TC=$TCDR610;
			break;;
		"DORI-6.2.X")
			TC=$TCDR620;
			break;;
		"LINARO-4.9.x")
			TC=$TCLN490;
			break;;
		"LINARO-5.3.x")
			TC=$TCLN530;
			break;;
		"LINARO-6.1.x")
			TC=$TCLN610;
			break;;
		"LINARO-6.3.x")
			TC=$TCLN630;
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
select CHOICE in D850 D851 D852 D855_16 D855_32 VS985 LS990 F400 CONTINUE_BUILD D855_STOCK_DEF D855_NCONF ALL; do
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
		"D855_16")
			CLEANUP;
			CUSTOM_DEF=gabriel_d855_16_defconfig
			MODEL=D855_16
			RAMDISK=D855
			REBUILD;
			break;;
		"D855_32")
			CLEANUP;
			CUSTOM_DEF=gabriel_d855_defconfig
			MODEL=D855_32
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
		"F400")
			CLEANUP;
			CUSTOM_DEF=gabriel_f400_defconfig
			MODEL=F400
			RAMDISK=F400
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
			echo "starting build of D855_16 in 3"
			sleep 1;
			echo "starting build of D855_16 in 2"
			sleep 1;
			echo "starting build of D855_16 in 1"
			sleep 1;
			CLEANUP;
			CUSTOM_DEF=gabriel_d855_16_defconfig
			MODEL=D855_16
			RAMDISK=D855
			REBUILD;
			echo "D855_16 is ready!"
			echo "starting build of D855_32 in 3"
			sleep 1;
			echo "starting build of D855_32 in 2"
			sleep 1;
			echo "starting build of D855_32 in 1"
			sleep 1;
			CLEANUP;
			CUSTOM_DEF=gabriel_d855_defconfig
			MODEL=D855_32
			RAMDISK=D855
			REBUILD;
			echo "D855_32 is ready!"
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
			echo "starting build of F400 in 3"
			sleep 1;
			echo "starting build of F400 in 2"
			sleep 1;
			echo "starting build of F400 in 1"
			sleep 1;
			CLEANUP;
			CUSTOM_DEF=gabriel_f400_defconfig
			MODEL=F400
			RAMDISK=F400
			REBUILD;
			echo "F400 is ready!"
			break;;
		"CONTINUE_BUILD")
			CONTINUE_BUILD;
			break;;
		"D855_STOCK_DEF")
			CUSTOM_DEF=$STOCK_DEF 
			RAMDISK=D855
			REBUILD;
			break;;
		"D855_NCONF")
			CUSTOM_DEF=$STOCK_DEF
			RAMDISK=D855
			REBUILD_NCONF;
			break;;
	esac;
done;
