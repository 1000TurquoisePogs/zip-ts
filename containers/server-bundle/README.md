# Zowe Docker file

## Requirements
 - docker
 - z/OSMF up and running
 - ZSS and ZSS Cross memory server up and running

**TL;DR**:
```sh
docker pull ompzowe/server-bundle:amd64
export DISCOVERY_PORT=7553
export GATEWAY_PORT=7554
export APP_SERVER_PORT=8544

#add non-default settings with --env, using same properties as seen in instance.env
#   --env ZOWE_ZLUX_TELNET_PORT=23
docker run -it \
    -h your_hostname \
    --env ZOWE_IP_ADDRESS=your.external.ip \
    --env LAUNCH_COMPONENT_GROUPS=DESKTOP,GATEWAY \
    --env ZOSMF_HOST=your.zosmainframe.com \
    --env ZWED_agent_host=your.zosmainframe.com \
    --env ZOSMF_PORT=11443 \
    --env ZWED_agent_https_port=8542 \
    --expose ${DISCOVERY_PORT} \
    --expose ${GATEWAY_PORT} \
    --expose ${APP_SERVER_PORT} \
    -p ${DISCOVERY_PORT}:${DISCOVERY_PORT} \
    -p ${GATEWAY_PORT}:${GATEWAY_PORT} \
    -p ${APP_SERVER_PORT}:${APP_SERVER_PORT} \
    --env GATEWAY_PORT=${GATEWAY_PORT} \
    --env DISCOVERY_PORT=${DISCOVERY_PORT} \
    --env ZOWE_ZLUX_SERVER_HTTPS_PORT=${APP_SERVER_PORT} \
    --mount type=bind,source=c:\temp\certs,target=/home/zowe/certs \
    ompzowe/server-bundle:amd64
```
Open browser and test it
 - API Mediation Layer: https://myhost.acme.net:7554
 - App Framework: https://myhost.acme.net:8544

## Building docker image
### Building docker image on Linux
Navigate to any subfolder of zowe-release for your computer architecture, such as s390x for zlinux or amd64 for intel linux.
For example, with an intel linux machine, to build v1 LTS you can execute:
```sh
cd dockerfiles/zowe-release/amd64/server-bundle
mkdir utils
cp -r ../utils/* ./utils
docker build -t zowe/docker:latest .
```

### Building docker image on Windows
Navigate to any subfolder of zowe-release/amd64.
For example, to build v1 LTS you can execute:
```powershell
cd dockerfiles/zowe-release/amd64/server-bundle
mkdir utils
copy ..\utils\* utils
docker build -t zowe/docker:latest .
```

## Executing Zowe Docker Container 
 - prepare folder with certificates, you should have it from previous step.
 - adjust `docker start` command
   - `-h <hostname>` - hostname of docker host (hostname of your laptop eg: myhost.acme.net)
   - `ZOWE_IP_ADDRESS=<ip>` - The IP which the servers should bind to. Should not be a loopback address.
   - `ZOSMF_HOST=<zosmf_hostname>` - z/OSMF hostname (eg mf.acme.net)
   - `ZOSMF_PORT=<zosmf_port>` - z/OSMF port eg (1443)
   - `ZWED_agent_host=<zss_hostname>` - ZSS host (eg mf.acme.net)
   - `ZWED_agent_https_port=<zss_port>` - ZSS port z/OSMF port eg (60012)
   - `source=<folder with certs>,target=<target dir within image>` - local folder containing external certs, and their target dir in the image (optional)
   - `EXTERNAL_CERTIFICATE=<keystore.p12>` - location of p12 keystore. (optional)
   - `EXTERNAL_CERTIFICATE_ALIAS=<alias>` - valid alias within keystore. (optional)
   - `EXTERNAL_CERTIFICATE_AUTHORITIES=<CA.cer>` - location of x509 Certificate Authority (optional)
   - `LAUNCH_COMPONENT_GROUPS=<DESKTOP or GATEWAY>` - what do you want to start
     - DESKTOP - only desktop
     - GATEWAY - only GATEWAY + explorers
     - GATEWAY,DESKTOP - both 

For example:

```cmd
DISCOVERY_PORT=7553 GATEWAY_PORT=7554 APP_SERVER_PORT=8544 docker run -it -h your_hostname --env ZOWE_IP_ADDRESS=your.external.ip --env LAUNCH_COMPONENT_GROUPS=DESKTOP,GATEWAY --env ZOSMF_HOST=your.zosmainframe.com --env ZWED_agent_host=your.zosmainframe.com --env ZOSMF_PORT=11443 --env ZWED_agent_https_port=8542 --expose ${DISCOVERY_PORT} --expose ${GATEWAY_PORT} --expose ${APP_SERVER_PORT} -p ${DISCOVERY_PORT}:${DISCOVERY_PORT} -p ${GATEWAY_PORT}:${GATEWAY_PORT} -p ${APP_SERVER_PORT}:${APP_SERVER_PORT} --env GATEWAY_PORT=${GATEWAY_PORT} --env DISCOVERY_PORT=${DISCOVERY_PORT} --env ZOWE_ZLUX_SERVER_HTTPS_PORT=${APP_SERVER_PORT} --env EXTERNAL_CERTIFICATE=/home/zowe/ext_certs/my.keystore.p12 --env EXTERNAL_CERTIFICATE_ALIAS=alias --env EXTERNAL_CERTIFICATE_AUTHORITIES=/home/zowe/ext_certs/myCA.cer --mount type=bind,source=<folder with certs>,target=/home/zowe/ext_certs ompzowe/server-bundle:amd64
```
Note: External certificates are optional and should not be included in the start command if undesired.

If you want to 
 - use it with different z/OSMF and ZSS change `ZOWE_ZOSMF_xxx` and `ZOWE_ZSS_xxx`
 - start only a component change `LAUNCH_COMPONENT_GROUPS`
 - run it on differen machine
    - move image to different machine
    -  execute `docker start` with updated `-h <hostname>`

### Windows
 - prepare folder with certificates 
   I have my certificates in `c:\workspaces\ZooTainers-Hackathon2019\certs`
```
c:\workspaces\ZooTainers-Hackathon2019\certs>dir
 Volume in drive C is Windows
 Volume Serial Number is 5EB2-BB6A

 Directory of c:\workspaces\ZooTainers-Hackathon2019\certs

10/10/2019  09:35 AM    <DIR>          .
10/10/2019  09:35 AM    <DIR>          ..
10/10/2019  09:12 AM             1,338 digicert_global_root_ca.cer
10/10/2019  09:12 AM             1,647 digicert_sha2_secure_server_ca_digicert_global_root_ca_.cer
10/10/2019  09:12 AM             2,472 server.cer
10/10/2019  09:12 AM             5,965 server.p12
               4 File(s)         11,422 bytes
               2 Dir(s)  179,745,226,752 bytes free
```
An example of `docker start` command
```cmd
set DISCOVERY_PORT=7553
set GATEWAY_PORT=7554
set APP_SERVER_PORT=8544

#add non-default settings with --env, using same properties as seen in instance.env
#   --env ZOWE_ZLUX_TELNET_PORT=23
docker run -it ^
    -h your_hostname ^
    --env ZOWE_IP_ADDRESS=your.external.ip ^
    --env LAUNCH_COMPONENT_GROUPS=DESKTOP,GATEWAY ^
    --env ZOSMF_HOST=your.zosmainframe.com ^
    --env ZWED_agent_host=your.zosmainframe.com ^
    --env ZOSMF_PORT=11443 ^
    --env ZWED_agent_https_port=8542 ^
    --expose %DISCOVERY_PORT% ^
    --expose %GATEWAY_PORT% ^
    --expose %APP_SERVER_PORT% ^
    -p %DISCOVERY_PORT%:%DISCOVERY_PORT% ^
    -p %GATEWAY_PORT%:%GATEWAY_PORT% ^
    -p %APP_SERVER_PORT%:%APP_SERVER_PORT% ^
    --env GATEWAY_PORT=%GATEWAY_PORT% ^
    --env DISCOVERY_PORT=%DISCOVERY_PORT% ^
    --env ZOWE_ZLUX_SERVER_HTTPS_PORT=%APP_SERVER_PORT% ^
    --mount type=bind,c:\workspaces\ZooTainers-Hackathon2019\certs,target=/home/zowe/certs ^
    ompzowe/server-bundle:amd64
```

### Linux
```cmd
export DISCOVERY_PORT=7553
export GATEWAY_PORT=7554
export APP_SERVER_PORT=8544

docker run -it \
    -h your_hostname \
    --env ZOWE_IP_ADDRESS=your.external.ip \
    --env LAUNCH_COMPONENT_GROUPS=DESKTOP,GATEWAY \
    --env ZOSMF_HOST=your.zosmainframe.com \
    --env ZWED_agent_host=your.zosmainframe.com \
    --env ZOSMF_PORT=11443 \
    --env ZWED_agent_https_port=8542 \
    --expose ${DISCOVERY_PORT} \
    --expose ${GATEWAY_PORT} \
    --expose ${APP_SERVER_PORT} \
    -p ${DISCOVERY_PORT}:${DISCOVERY_PORT} \
    -p ${GATEWAY_PORT}:${GATEWAY_PORT} \
    -p ${APP_SERVER_PORT}:${APP_SERVER_PORT} \
    --env GATEWAY_PORT=${GATEWAY_PORT} \
    --env DISCOVERY_PORT=${DISCOVERY_PORT} \
    --env ZOWE_ZLUX_SERVER_HTTPS_PORT=${APP_SERVER_PORT} \
    --mount type=bind,source=c:\temp\certs,target=/home/zowe/certs \
    ompzowe/server-bundle:amd64
```

#### Expected output
When running, the output will be very similar to what would be seen on a z/OS install, such as:

```
put something here
```

## Test it
Open browser and test it
 - API Mediation Layer: https://mf.acme.net:7554
 - API ML Discovery Service: https://mf.acme.net:7553/
 - App Framework: https://mf.acme.net:8544

## Using Zowe's Docker with Zowe products & plugins
To use Zowe-based software with the docker container, you must make that software visible to the Zowe that is within Docker by mapping a folder on your host machine to a folder visible within the docker container.
This concept is known as Docker volumes. After sharing a volume, standard Zowe utilities for installing & using plugins will apply.

To share a host directory *HOST_DIR* into the docker container destination directory *CONTAINER_DIR* with read-write access, simply add this line to your docker run command: `-v [HOST_DIR]:[CONTAINER_DIR]:rw`
You can have multiple such volumes, but for Zowe Application Framework plugins, the value of *CONTAINER_DIR* should be `/home/zowe/apps`

An example is to add Apps to the Zowe Docker by sharing the host directory `~/apps`, which full of Application Framework plugins.

```cmd
export DISCOVERY_PORT=7553
export GATEWAY_PORT=7554
export APP_SERVER_PORT=8544

docker run -it \
    -h your_hostname \
    --env ZOWE_IP_ADDRESS=your.external.ip \
    --env LAUNCH_COMPONENT_GROUPS=DESKTOP,GATEWAY \
    --env ZOSMF_HOST=your.zosmainframe.com \
    --env ZWED_agent_host=your.zosmainframe.com \
    --env ZOSMF_PORT=11443 \
    --env ZWED_agent_https_port=8542 \
    --expose ${DISCOVERY_PORT} \
    --expose ${GATEWAY_PORT} \
    --expose ${APP_SERVER_PORT} \
    -p ${DISCOVERY_PORT}:${DISCOVERY_PORT} \
    -p ${GATEWAY_PORT}:${GATEWAY_PORT} \
    -p ${APP_SERVER_PORT}:${APP_SERVER_PORT} \
    --env GATEWAY_PORT=${GATEWAY_PORT} \
    --env DISCOVERY_PORT=${DISCOVERY_PORT} \
    --env ZOWE_ZLUX_SERVER_HTTPS_PORT=${APP_SERVER_PORT} \
	-v ~/apps:/home/zowe/apps:rw \
    ompzowe/server-bundle:amd64 $@
```

By default, external plugins in the ```/home/zowe/apps``` folder will be installed at start up.

To install other plugins to the app server simply ssh into the docker container to run the install-app.sh script, like so:
```docker exec -it [CONTAINER_ID] /home/zowe/instance/bin/install-app.sh [APPLICATION_DIR]```
If the script returns with rc=0, then the plugin install succeded and the plugin can be used by refreshing the app server via either clicking "Refresh Applications" in the launchbar menu of the Zowe Desktop, or by doing an HTTP GET call to /plugins?refresh=true to the app server.


## Using an external instance of Zowe
If you have an instance of Zowe on your host machine that you want to use you can mount a shared volume and set the location of the shared volume as an environmental variable called EXTERNAL_INSTANCE. This can by done by adding these two flags to your docker start script.

```
-v ~/my_instance:/home/zowe/external_instance:rw \
--env EXTERNAL_INSTANCE=/home/zowe/external_instance \
```
