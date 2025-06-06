
Update  _motioneye_  camera config with the updated ip address of my v380 cctv camera (or possibly any other camera).

**Reason for creating the script:**
I run motioneye on a docker container with the config exposed. Whenever there was a power outage/router reboot/cctv restart, I had to manually change the config so that motioneye will be able to use the new ip address of the camera. This script automates the task and can bring back up the camera recording in a few minutes.

familiarity of the following is required: 
 - basic systemd service and timers 
  - bash script 
  - nmap

***Note:*** You will need to edit the paths and mac address from all thress files (service,timer,script) for it to work. nmap is requred to be install for the script to function.
