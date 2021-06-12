#!/bin/bash

BACKUP_NAME="$(date +"%Y_%m_%d_%I_%M")"
TARGETS=('/home' '/etc/' '/var/log')
BACKUP_ROOT='./backup'
BACKUP_DIR="${BACKUP_ROOT}/${BACKUP_NAME}"

if test -f "./pass"; then
  PASS="$(cat ./pass)"
  echo "Password file found."
else
	echo 'Password file not found. Generating one to "./pass".'
	gpg --gen-random 2 32 > ./pass
	PASS="$(cat ./pass)"
	chmod 400 ./pass
fi
echo ""

if [ "$1" == "-d" ]; then
	gpg --yes --batch --decrypt --passphrase=$PASS $2 | tar xz --strip-components 2
	exit
else
	mkdir $BACKUP_ROOT &>/dev/null
fi

read -p 'FTP hostname : ' FTP_HOST

read -p '	╚ username : ' FTP_USERNAME

read -s -p '	╚ password : ' FTP_PASS
echo ""

LOGIN_ATTEMPT="$(ftp -inv $FTP_HOST << EOF
user $FTP_USERNAME $FTP_PASS
bye
EOF
)"

if [[ "$(echo $LOGIN_ATTEMPT)" =~ "User logged in" ]]; then
	echo ""
	echo "login success"
else
	echo ""
	echo "login attempt failed"
	exit
fi

mkdir -p $BACKUP_DIR &>/dev/null

for i in ${TARGETS[@]}; do
	echo ""
	echo "$(date "+%D %R") : backing up $i ..."
	if sudo rsync -Ra $i ${BACKUP_DIR}; then
		echo "	╚ $(date "+%D %R") : Successfully backed up $i"
	else
		echo "	╚ $(date "+%D %R") : Failed backing up $i"
	fi
done

echo ""
echo "$(date "+%D %R") : Beginning compression and encryption of ${BACKUP_DIR}"
sudo tar -zcf "${BACKUP_DIR}.tar.gz" ${BACKUP_DIR}
gpg --symmetric --yes --batch --cipher-algo AES256 --compress-algo none --passphrase="$PASS" ${BACKUP_DIR}.tar.gz
echo ""
echo "$(date "+%D %R") : Successfully compressed ${BACKUP_DIR}"

echo ""
echo "$(date "+%D %R") : Beginning transfert of backup"
echo ""
ftp -inv $FTP_HOST << EOF
user $FTP_USERNAME $FTP_PASS
binary
lcd $BACKUP_ROOT
put $BACKUP_NAME.tar.gz.gpg
bye
EOF
echo ""
sudo rm -Rf $BACKUP_ROOT
echo "$(date "+%D %R") : Job finish"
