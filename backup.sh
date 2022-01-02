#!/bin/bash

BACKUP_NAME="$(date +"%Y_%m_%d_%I_%M")"
TARGETS=('/home' '/etc/' '/var/log')
BACKUP_ROOT='./backup'
BACKUP_DIR="${BACKUP_ROOT}/${BACKUP_NAME}"

if test -f "./.pass"; then
  PASS="$(cat ./.pass)"
  echo "Password file found."
else
        echo 'Password file not found. Generating one to "./.pass".'
        gpg -a --gen-random 2 256 > ./.pass
        PASS="$(cat ./.pass)"
        chmod 400 ./.pass
fi
echo ""

if [ "$1" == "-d" ]; then
        gpg --yes --batch --decrypt --cipher-algo "AES256" --passphrase="$PASS" $2 | tar xz 
        exit
else
        mkdir $BACKUP_ROOT &>/dev/null
fi

read -p 'FTP hostname : ' FTP_HOST

read -p '    ╚ username : ' FTP_USERNAME

read -s -p '    ╚ password : ' FTP_PASS
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
        if sudo rsync --exclude "$(cd "$(dirname "$BACKUP_DIR")"; pwd)/$(basename "$BACKUP_DIR")" -Ra $i ${BACKUP_DIR}; then
                echo "  ╚ $(date "+%D %R") : Successfully backed up $i"
        else
                echo "  ╚ $(date "+%D %R") : Failed backing up $i"
        fi
done

echo ""
echo "$(date "+%D %R") : Beginning compression and encryption of ${BACKUP_DIR}"
sudo tar -zc ${BACKUP_DIR} | gpg --symmetric --yes --batch --cipher-algo "AES256" --compress-algo none --passphrase="$PASS" -o "$BACKUP_NAME.tar.gz.gpg"
echo ""
echo "$(date "+%D %R") : Successfully compressed ${BACKUP_DIR}"

echo ""
echo "$(date "+%D %R") : Beginning transfert of backup"
echo ""
ftp -inv $FTP_HOST << EOF
user $FTP_USERNAME $FTP_PASS
binary
put $BACKUP_NAME.tar.gz.gpg
bye
EOF
echo ""
sudo rm -Rf $BACKUP_NAME.tar.gz.gpg
sudo rm -Rf $BACKUP_ROOT
echo "$(date "+%D %R") : Job finish"