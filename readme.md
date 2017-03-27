# Installation

Run as root
```
bash <(curl -Ls https://raw.githubusercontent.com/amvmoody/hifi-kickstart/master/setup.sh)
```

# Usage 

- --save : Creates a backup of the live codebase
-  --status : give status info on the hifi.service
-  --update : Creates a backup of the current live folder then updates the code.
-  --restore : restore code from one of the last backups
-  The process is controlled by systemd, to start, restart, stop etc. use systemctl <start,stop,restart,status> hifi.service