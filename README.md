# linux-backup
Bash script to backup folders into an archive file, encrypt this file and send it to a remote FTP server.

### Execution
You can simply execute this script to to the backup and encryption job.
```
./backup.sh
```

You can uncrypt and decompress a downloaded backup by using the option '-d':
```
./backup.sh -d ./2021_06_04_11_28.tar.gz.gpg
```
