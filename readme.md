# Installation

Run as root
```
bash <(curl -Ls https://raw.githubusercontent.com/amvmoody/hifi-server/master/setup.sh)
```

# Usage 

- hifi --save : Creates a backup of the live codebase.
- hifi --status : Gives status info on the hifi services.
- hifi --update : Creates a backup of the current live folder then updates the code.
- hifi --update-hifi-server : Updates this build tool.
- hifi --restore : Restore code from one of the last backups.
- hifi --stop : stops Hifi.
- hifi --start : Starts Hifi.
- hifi --restart : Restarts Hifi.