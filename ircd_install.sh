#!/bin/bash

USERNAME="irc"
PREFIX="/usr/local/ircd"

# Function to prompt for [y/n], return true or false
confirm () {
	if [ $FORCE ]; then return 0 ; fi
	read -r -p "${1:-Are you sure ? [y/n]}" response
	case $response in
		[yY][eE][sS]|[yY]|"")
			true
			;;
		*)
			false
			;;
	esac
}

# Function to create a system user
create_user () {
	confirm "This will create a system user, are you sure ? [y/n] " && \
		useradd -r $1
}

# Function to display errors
error () {
	case $1 in
		spec_u) echo "If you want to specify an user, rerun with -u <username>"
		;;
		no_crea) echo "Can't work without user, exiting now"
		;;
		no_root) echo "You must run this scrip as root"
		;;
	esac
	exit 1
}

# Usage
usage () {
	echo usage
}

# Verify if launched as root
if [ "$(id -u)" != 0 ]; then error "no_root"; fi

# Get flags
while test $# != 0
do
	case $1 in
		-f|--force) FORCE=true ;;
		-u|--user)
			shift
			case $1 in
				-*) usage ; break ;;
				*)
				getent passwd $1 >/dev/null 2&>1 && USERNAME=$1 || \
				{ confirm "User $1 doesn't exists, do you want to create it ? [y/n] " && \
					create_user $1 || error "no_crea" ; } && shift
				;;
			esac
		;;
		-p|--prefix)
			shift
			case $1 in
				/*|~*)
				PREFIX=$1 &&
				confirm "Use $PREFIX for installing ircd ?" && shift
				;;
				*) usage ; break ;;
			esac
		;;
		--) shift ; break ;;
		-*) usage ; break ;;
	esac
	shift
done

# Get appropriate confirmation message
case $USERNAME in
	irc) message="This script will use the default debian user irc to run the ircd
and the services, do you agree ? [y/n] "
	;;
	*) message="This script will use the user $USERNAME to run the ircd
and the services, do you agree ? [y/n] "
	;;
esac

# Check if the user is right
confirm "$message" || error "spec_u"

# Shortcut to launch cmds as user
SU_CMD="su $USERNAME -s /bin/sh -c "

# Cloning all sources
echo "Cloning sources in /tmp"
	echo "Cloning ircd-hybrid"
		$SU_CMD "git clone https://github.com/ircd-hybrid/ircd-hybrid.git /tmp/ircd-hybrid"
	echo "Cloning Anope"
		$SU_CMD "git clone https://github.com/anope/anope.git /tmp/anope"

echo "Compiling and installing ircd-hybrid"
	mkdir $PREFIX
	chown $USERNAME:$USERNAME $PREFIX
	$SU_CMD "cd /tmp/ircd-hybrid ; ./configure --prefix=$PREFIX; make && make install"

echo "Preparing anope compilation"
	mkdir "$PREFIX/../services"
	chown $USERNAME:$USERNAME "$PREFIX/../services" 
	# Creating config file
	cat > /tmp/anope/config.cache <<- EOF
		INSTDIR="$PREFIX/../services"
		RUNGROUP="irc"
		UMASK=007
		DEBUG="no"
		USE_PCH="no"
		EXTRA_INCLUDE_DIRS=""
		EXTRA_LIB_DIRS=""
		EXTRA_CONFIG_ARGS=""
	EOF

echo "Compiling and installing anope"
$SU_CMD "cd /tmp/anope/ ; ./Config -quick ; cd build ; make && make install"

HASH= $SU_CMD "$PREFIX/bin/mkpasswd -5 -p ponyplay"

cat toto | sed -e '1h;1!H;${g;s/\n\(log {.*};\)/\n\/\*\1\*\//g;p;}'
