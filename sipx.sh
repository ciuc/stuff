#!/bin/bash
START=$(date +%s)
#DEFAULTS:
SIPX_DIR=/home/ciuc/sipx/WORKING
SRC_DIR=$SIPX_DIR/main
BUILD_DIR=$SIPX_DIR/BUILD
INSTALL_DIR=$SIPX_DIR/INSTALL

usage="Usage: $0 {-c command [options]}. Type $0 -h man for a more detailed help"

printHelp=0
verbose=0
buildBeforeTest=0
buildgwt=0
testsuite='test-all'
hard_restart=0
kill_sipxpresence=0
run_autoreconf=0
while getopts 'hvxgukadc:t:b:s:e:p:' o
do case "$o" in
h) printHelp=1;;
b) branch="$OPTARG"
SIPX_DIR=/home/ciuc/stuff/sipx/BRANCHES/$branch
SRC_DIR=$SIPX_DIR/main/
BUILD_DIR=$SIPX_DIR/BUILD
INSTALL_DIR=$SIPX_DIR/INSTALL
;;
c)command="$OPTARG";;
t)testName="$OPTARG";;
u)buildBeforeTest="$OPTARG";;
s)serverCommand="$OPTARG";;
v)verbose=1;;
x)openfire=1
SIPX_DIR=/home/ciuc/sipx/OPENFIRE
SRC_DIR=$SIPX_DIR/src/project_xmpp
BUILD_DIR=$SIPX_DIR/BUILD
INSTALL_DIR=$SIPX_DIR/INSTALL
;;
g)buildgwt=1;;
e)testsuite="$OPTARG";;
d)hard_restart=1;;
k)kill_sipxpresence=1;;
p)project="$OPTARG";;
a)run_autoreconf=1;;
[?])    echo >&2 $usage
exit 1;;
esac
done

#Runs a make install
makeinstall(){
	srv stop &
	cd $BUILD_DIR/sipXconfig
	make && make install
	RETVAL=$?
	srv start
	return $RETVAL
}

#Does a make install on all projects
makeinstallall(){
	srv stop &
	cd $BUILD_DIR
	make && make install
	srv start
}

makeinstallsupervisor(){
	srv stop &
	pid=$!
	cd $BUILD_DIR/sipXsupervisor
	make && make install
	wait $pid
	srv start
}

#Does a clean install as installing for the first time
auto_reconf(){
	echo "ARE YOU SURE YOU WANT TO RUN AUTORECONF (IT WILL DELETE BUILD AND INSTALL DIR AND LAST ALMOST 1 HOUR)? yes/no"
	read run;
	if [ "$run" != "yes" ];then
		echo "Autoreconf aborted!"
		exit 0;
	fi
	srv stop
	echo -e "\E[;31mMaking a clean install"
	echo -e "\E[;31mDeleting $BUILD_DIR and $INSTALL_DIR..."
	rm -rf $BUILD_DIR
	rm -rf $INSTALL_DIR
	mkdir $BUILD_DIR
	mkdir $INSTALL_DIR
	echo -e "\E[;31mMoving to $SRC_DIR..."
	cd $SRC_DIR
	echo -e "\E[;31mConfiguring..."
	tput sgr0	
	autoreconf -if
	cd $BUILD_DIR
	echo -e "\E[;31mInstalling..."
	tput sgr0
	if [ $verbose -eq 1 ];then
		echo -e "\E[;31m~~~~~~ in `pwd` ~~~ JAVAC_DEBUG=on JAVAC_OPTIMIZED=off $SRC_DIR/configure --cache-file=`pwd`/ac-cache-file SIPXPBXUSER=`whoami` SIPXPBXGROUP=`whoami` OPENFIRE_HOME=/opt/openfire prefix=`pwd`/../INSTALL --disable-doxygen --disable-doc --enable-mrtg --enable-cdr --enable-reports --enable-agents -enable-agent --enable-conference JAVAC_DEBUG=on JAVAC_OPTIMIZED=off --with-distdir=`pwd`/dist --enable-openfire OPENFIRE_HOME=/opt/openfire ~~~"
		tput sgr0
	fi
	tput sgr0
#	JAVAC_DEBUG=on JAVAC_OPTIMIZED=off $SRC_DIR/configure --cache-file=`pwd`/ac-cache-file SIPXPBXUSER=`whoami` SIPXPBXGROUP=`whoami` OPENFIRE_HOME=/opt/openfire prefix=$INSTALL_DIR --disable-doxygen --disable-doc --enable-mrtg --enable-cdr --enable-reports --enable-agents -enable-agent --enable-conference JAVAC_DEBUG=on JAVAC_OPTIMIZED=off --with-distdir=`pwd`/dist --enable-openfire OPENFIRE_HOME=/opt/openfire --disable-licensing

        $SRC_DIR/configure --cache-file=`pwd`/ac-cache-file --prefix=$INSTALL_DIR JAVAC_DEBUG=on JAVAC_OPTIMIZED=off

	#small hack to build openfire correctly
	#cp ~/sipx/Makefile.openfire $BUILD_DIR/sipXopenfire/Makefile
	#export b=$BUILD_DIR/sipXopenfire/Makefile
	#export b1=$BUILD_DIR/sipXopenfire/Makefile1
	#cp $b ~/stuff/bck/
	#mv $b $b1
	#sed -e 's/BUILD_ANT = /BUILD_ANT = all-ant/g' -e 's/CHECK_ANT =/CHECK_ANT = check-ant/g' -e 's/INSTALL_ANT =/INSTALL_ANT = install-ant/g' -e 's/#bin_SCRIPTS = sipxopenfire.sh sipxopenfire-initdb.sql sipxopenfire-setup.sh/bin_SCRIPTS = sipxopenfire.sh sipxopenfire-initdb.sql sipxopenfire-setup.sh/g'  $b1 > $b
        #rm -f $b1
        echo -e "\E[;31mPerforming make build..."
	tput sgr0
	make build
#checking out the time so far:
END=$(date +%s)
DIFF=$(( $END - $START ))
mins=$(($DIFF/60))
out="\E[;31mScript took $DIFF seconds that is around $mins minutes"
echo -e $out" `date`";
tput sgr0
######        
	echo -e "\E[;31mBringing up the setup screen..."
	tput sgr0
	cd $INSTALL_DIR/bin
	./sipxecs-setup
}

#Precommit
precommit(){
	if [ $buildgwt -ne 1 ];then
         change_gwt_build
        fi
	rm -rf $SRC_DIR/sipXconfig/neoconf/bin.eclipse
	rm -rf $SRC_DIR/sipXconfig/web/bin.eclipse
	cd $SRC_DIR/sipXconfig
	ant precommit
        RETVAL=$?
        if [ $buildgwt -ne 1 ];then
                change_back_gwt_build
        fi
        return $RETVAL
}

#Runs commands on the server. Commands are: {start|stop|status|configtest|restart}
srv(){
	#export SIPXCONFIG_OPTS="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=4241"
	if [ $kill_sipxpresence -eq 1 ] && [ "$1" == "stop" ];then
	  killall $INSTALL_DIR/bin/sipxpresence
	  killall $INSTALL_DIR/bin/sipxpresence 
	  killall $INSTALL_DIR/bin/sipxpresence
	  killall $INSTALL_DIR/bin/sipxpresence &
	  killall $INSTALL_DIR/bin/sipxpresence &
	  killall $INSTALL_DIR/bin/sipxrls
	  killall $INSTALL_DIR/bin/sipxrls
	  killall $INSTALL_DIR/bin/sipxrls
	  killall $INSTALL_DIR/bin/sipxrls &
	  killall $INSTALL_DIR/bin/sipxrls &
	fi
	cd $INSTALL_DIR/etc/init.d
	echo Running $1 on server
	sudo ./sipxecs $1
}

#Moves to source directory, build and copy files to server
build_sipxconfig(){
	if [ $hard_restart -eq 1 ];then
	  srv stop &
	  pid=$!
        fi
	if [ $buildgwt -ne 1 ];then
	 change_gwt_build
	fi
	cd $SRC_DIR/sipXconfig
	if [ $verbose -eq 1 ];then
		echo -e "\E[;31m~~~~~~ in `pwd` ~~~  running ant ~~~"
		tput sgr0
	fi
	ant
	if [ $verbose -eq 1 ];then
		echo -e "\E[;31m~~~~~~ in `pwd` ~~~  cp $BUILD_DIR/sipXconfig/neoconf/dist/sipxconfig.jar $INSTALL_DIR/share/java/sipXecs/sipXconfig/sipxconfig.jar ~~~"
		echo -e "\E[;31m~~~~~~ in `pwd` ~~~  cp $BUILD_DIR/sipXconfig/web/dist/sipxconfig.war $INSTALL_DIR/share/java/sipXecs/sipXconfig/sipxconfig.war ~~~"
		tput sgr0
	fi
	cp $BUILD_DIR/sipXconfig/neoconf/dist/sipxconfig.jar $INSTALL_DIR/share/java/sipXecs/sipXconfig/sipxconfig.jar
	cp $BUILD_DIR/sipXconfig/web/dist/sipxconfig.war $INSTALL_DIR/share/java/sipXecs/sipXconfig/sipxconfig.war
        rm -f $INSTALL_DIR/share/java/sipXecs/sipXconfig/Ciscospa-phones.jar
	if [ $hard_restart -eq 1 ];then
          wait $pid
	  srv start
        else
	  $INSTALL_DIR/bin/sipxproc --restart ConfigServer
        fi
	if [ $buildgwt -ne 1 ];then
		change_back_gwt_build
	fi
}

#make a project other config
make_project() {
	cd $SRC_DIR/$project
	if [ $run_autoreconf -eq 1 ];then
		autoreconf -if
		cd $BUILD_DIR/$project
		make distclean
		$SRC_DIR/$project/configure --cache-file=`pwd`/ac-cache-file --prefix=$INSTALL_DIR JAVAC_DEBUG=on JAVAC_OPTIMIZED=off
	fi
	cd $BUILD_DIR/$project
	make && make install 
}

ant_install(){
        if [ $hard_restart -eq 1 ];then
          srv stop &
          pid=$!
        fi
	if [ $buildgwt -ne 1 ];then
		change_gwt_build
	fi
	cd $SRC_DIR/sipXconfig
	ant clean && ant && ant install
        rm -f $INSTALL_DIR/share/java/sipXecs/sipXconfig/Ciscospa-phones.jar
        if [ $hard_restart -eq 1 ];then
          wait $pid
          srv start
        else
          $INSTALL_DIR/bin/sipxproc --restart ConfigServer
        fi

	if [ $buildgwt -ne 1 ];then
		change_back_gwt_build
	fi
}

#Run a test; if second param is 1 it will build first
run_test(){
	change_gwt_build
	cd $SRC_DIR/sipXconfig
	#TODO: vezi ca aici tre sa verifici daca param 2 e null
	if [ $2 -eq 1 ];then
		echo -e \E[;31mClean and compile...
		tput sgr0
		ant clean && ant
	fi
	echo -e "\E[;31mRunning test $1"
	tput sgr0
	#ant test-all -Dtest.name=$1
	if [ $testsuite == 'test-ui' ];then
	 cd web
	else if [ $testsuite == 'single-test-integration' -o $testsuite == 'single-test-db' ];then
               cd neoconf
             fi
	fi
	ant $testsuite -Dtest.name=$1
	change_back_gwt_build
}

clear_db(){
	export user=`whoami`
	if [ $user != 'root' ];then
		echo -e "\E[;31mFor now only root can run this command!"
		tput sgr0
		exit 4
	fi
	/etc/rc.d/init.d/postgresql stop
        cp /var/lib/pgsql/data/pg_hba.conf ~/
        cp /var/lib/pgsql/data/postgresql.conf ~/
	rm -rf /var/lib/pgsql/data
	su - postgres -c "initdb /var/lib/pgsql/data"
        cp ~/pg_hba.conf /var/lib/pgsql/data/
        cp ~/postgresql.conf /var/lib/pgsql/data/
	#$INSTALL_DIR/bin/sipxconfig.sh --setup
	#$INSTALL_DIR/bin/sipxconfig.sh --database-upgrade
}

checkstyle() {
	cd $SRC_DIR/sipXconfig
        ant style
}

change_gwt_build(){
export b=$SRC_DIR/sipXconfig/gwt/build.xml
export b1=$SRC_DIR/sipXconfig/gwt/build1.xml
mv $b $b1
sed -e 's/<antcall target="gwt.compile.module.userportal" \/>/<!--antcall target="gwt.compile.module.userportal" \/-->/g' $b1 > $b
rm -f $b1 
}

change_back_gwt_build(){
export b=$SRC_DIR/sipXconfig/gwt/build.xml
export b1=$SRC_DIR/sipXconfig/gwt/build1.xml
mv $b $b1
sed -e 's/<!--antcall target="gwt.compile.module.userportal" \/-->/<antcall target="gwt.compile.module.userportal" \/>/g' $b1 > $b
rm -f $b1
}

print_help(){
	help="To create a patch:\n\
- make sure you are on the branch (git status)\n\
- git commit -a\n\
- git-format-patch master -o /home/ciuc/sipx/patch/XCF-???? --check\n\
- view the patch and check if you have spaces and if everything else is ok\n\
- if so, correct the errors and run git commit -a --amend\n\
- git-format-patch master -o /home/ciuc/sipx/patch/XCF-????\n\
--------
Use: export SIPXCONFIG_OPTS=\"-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=4241\" for debug.\n
To get a test container running cd to $SRC_DIR/sipXconfig/web and type ant run
"
	man="Usage: $0 -c command\n\
Commands are:\n\
makeinstall - runs a make install ON SIPXCONFIG\n\
test - runs a specific test; if second argument is 1 it will perform a build first\n\
autoreconf - configures and make install as if running for the first time; it will bring up at the end the setup screen\n\
precommit - runs a precommit\n\
srv - runs a command (using sudo) on server - cannot be used when debug is needed\n\
build - performs a build\n\
cleardb - clears the db - for the moment, run as root\n\
makeinstallall - does a make and make install on all projects (might take a while)
Other option arguments:\n\
-b branch - leave blank for main, 4.0 for 4.0 branch\n\
-t testName - the test to run (used with test command)\n\
-b 0|1 - 1 to build before test, 0 otherwise\n\
-s serverCommand - the command to run on the server (used srv command)\n\
-h [man] - prints help\n\
-v - verbose; prints out some more info about the actions performed\n\
-e test-suite; one of test-ui, test-web, etc. defaults to test-all\n\
"
	if [ "$1" == "man" ];then
	  echo -e "$man";
	else
	  echo -e "\E[;31m$help"
	fi
	tput sgr0
	#echo $usage
	exit 1	
}

if [ "$printHelp" -eq 1 ];then
	print_help $2;
fi

if [ "$branch" != "" ];then
	echo -e "\E[;31mOn branch $branch"
	tput sgr0
else 
	echo -e "\E[;31mOn branch main"
	tput sgr0
fi


case $command in
        srv)
                srv $serverCommand
	;;
	restart)
		srv restart
	;;
	stop)
		srv stop
	;;
	start)
		srv start
	;;
	precommit)
		precommit
	;;
	build)
		build_sipxconfig
	;;
	makeinstall)
		makeinstall
	;;
	makeinstallall)
		makeinstallall
	;;
	makeinstallsuperv)
		makeinstallsupervisor
	;;
	precommit)
		precommit
	;;
	autoreconf)
		auto_reconf
	;;
	cleardb)
		clear_db
	;;
	antinstall)
		ant_install
	;;
	test)
		run_test $testName $buildBeforeTest
	;;
	style)
		checkstyle
	;;
	makeprj)
		make_project
	;;
	*)
        	echo $usage
        	exit 3
	;;
esac



END=$(date +%s)
DIFF=$(( $END - $START ))
mins=$(($DIFF/60))
out="\E[;31mScript took $DIFF seconds, that is "
if [ $mins -lt 1 ];then
  out+="less than one minute."
else
  out+="around $mins minutes"
fi
echo -e $out" `date`";
tput sgr0
