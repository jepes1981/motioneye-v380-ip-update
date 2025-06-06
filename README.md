Update *motioneye* camera config with the updated ip address of my v380 cctv camera (or possibly any other camera).

**Reason for creating the script:**
I run motioneye on a docker container with the config exposed. Whenever there was a power outage/router reboot/cctv restart, I had to manually change the config so that motioneye will be able to use the new ip address of the camera. This script automates the task and can bring back up the camera recording in a few minutes.
