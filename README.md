# zetapkgs
Installable packages for the Zeta Architecture based on on zetadcos
---------
While DCOS currently has the universe and packages, there is a key differentiator between Zeta as we've layed out and DCOS: Shared storage. 

DCOS assumes no shared storage, we assume shared storage, and then build off that: this allows performance, scalability, isolation, security, and audit. Now, the current package manager doesn't have features that allow us to really use our shared storage. 

What does this mean?

Well, there are things, like creating shared storage volumes (in any filesystem) for isolation, permissions, locations of configurations, local storage of docker containers, of executor URIs, custom builds etc that the no shared storage model lacks. 

Great, so we have two approaches... what is this then? 

In trying to deconflict features of DCOS Package Management and using shared storage, I wanted a way to have people install pacakges, and then identify new packages, as well as outline those features that could be baked into DCOS to allow a unifed apprach. 

A unified apprach? How does that work if DC/OS assumes no shared storage?

Well, there has been talk around "cluster capabilties" for packages. I.e. a package wouldn't install if the dest cluster didn't have a capability requirement, one of those may be "shared storage".  

With that idea, could we identify the gaps in how we are installing with shared storage, and the features the dcos package installer has, and try to add features to allow us to unify package installs to using only the DCOS package installer in the future?

*THAT* is the goal here. The goal isn't to forever maintain a speparate way to install packages, instead, it's to demostrate features, that we may use with a shared storage install, and then look to work with DCOS community in adding the those features.

### The End Goal is to use the DC/OS Package Manager

---------

## Initial Approach

We are using the maprdcos and zetadcos packages as a base. 

maprdcos: https://github.com/JohnOmernik/maprdcos

zetadcos: https://github.com/JohnOmernik/zetadcos

Thus we can make some assumptions:

* Shared Storage (as stated above) - A shared filesystem accessible to all agents at the same mount point and via the HDFS API
* A basic directory structure (apps,data,etl,zeta) that can be "assumed" to be present
* A directory server (openldap in reference architecture, or if someone plug and played their internal AD server)
* At least one role, "shared" as a base location for shared services. 
* Role per directory, for the 4 directories above, roles can be installed and a directory for each role is created in each directory. 

To install packages, simply clone this repo (with maprdcos and zetadcos installed) cd zetapkgs

from here Run ./install.sh $APP_NAME

Note: $APP_NAME is the name of the package, spark, gogs, kafka etc. 

Certain packages will rely on other packages, and they won't install without the requried packages.  All packages require the "preinst" package to be installed, so install that one first:

./install.sh preinst

That will install your package (copy the package builders/installer to /mapr/$CLUSTERNAME/zeta/shared/$APP_NAME)  Follow instructions from there. 

---------

### States
A package will have various states of installation. 

#### Not installed
There is no evidence of installation on the cluster, nothing running, nothing in directories

#### Preinstalled/Staged
In this state, a base install is setup locally for further installation.  This information is located in /(apps/etl/zeta)/shared/$APP_NAME  At this point there is nothing in the cluster "running" but located in the install location/local docker registries is:
* Docker files for any images used in the install
* Multiple versions of the application can be stored here for use in different instances
* Images either pulled or built locally, tagged to the cluster, and stored in a local docker registry
* Executor/Scheduler tarballs for frameworks/tasks, for specific versions. Ideally, versioned apps should be as generic as possible, with configurations applied later (during install) 
* The exception to the generic approach is any cluster/zeta specific install scripts (creating volumes, etc) should located in this staged/preinstall location. 

#### Instance Installed - Not Running
In this state there is a specific named instance installed into a specific role.  It is not running, but a configuration has been created and customized for the instance.  Most packages will be multi-instance/multi-role, but there could be cases where certain packages may only allow one install per role, or one install per cluster (if this is the case, it MUST be installed in the shared role). 

#### Instance Running
This is the next logical step. After the config is generated, run it on the cluster.  

#### Instance Removed - Application staged
At this point, individual instance installs are removed, including their specific configuration, but the shared staged files still exist. 

### Locations

All potential applications have a name: all lower case letters or numbers - no special characters $APP_NAME
All instances will have a name: $APP_ID
Roles are denoted by $APP_ROLE
Base dirs (apps, data, etl, zeta) will be denoted by %APP_DIR% - Note: this is almost always a recommended location, and actually up to the end user. 

Where things are located are going to be based on where something is installed, and the role it is assigned to. 

The preinstall/staged information is the exception.  


All stage information will be at /zeta/shared/$APP_NAME/stage
All instances will be at /$APP_DIR/$APP_ROLE/$APP_NAME/$APP_ID

So for example, if I am using spark in an production etl job, I would probably have two directories:

/zeta/shared/spark/stage - In which my tgz for execution may be /zeta/shared/spark/stage/packages and then a "install_instance.sh" file in /zeta/shared/spark/stage

When I install my instance for my etl, it may be on firewall logs, so I give it a ID of sparkfwlogs  thus the conf files for, and code may be located in:

/etl/prod/spark/sparkfwlogs

the folder with an id is an instance, and the staged/preinstall are the files it may use.  

(Please note, this is a brain dump and will likely change going forward as I learn from others)



### Variables
------------
Certain variables are available during the installer phases. These are often set by the scripts or the include files, other times they are set during the install by asking for user intervention. 
* Todo: make it so we can use json file to set all variables for unattended install, right now these are manual)

Assume a preceding $ on these in the bash scripts

~~~~~
APP_NAME # The Name of the package or app. THis isn't the instance of a give app this is the app in general. Spark, Kafka, etc. 
APP_ROOT # Shortcut for the "installer" location, not the installed location. This is where the scripts are for installing things, not the actual instances: /mapr/$CLUSTERNAME/zeta/shared/$APP_NAME
APP_PKG_DIR # This is where built packages (if not docker images) are stored for the instances. It ends up being /mapr/$CLUSTERNAME/zeta/shared/$APP_NAME/packages (or $APP_ROOT/packages)
APP_DIR # This is the directory the instance will be installed in. Many apps have RECDIR which is the recommended directory, however the user can update this if they want go all maverick
APP_ROLE # The role the instance will be installed in 
APP_ID # The actual instance name. So the kafka APP_NAME may have an instance in APP_ROLE: Prod with an APP_ID of kafkaproduction
APP_HOME # Where the actual app is installed, /mapr/$CLUSTERNAME/$APP_DIR/$APP_ROLE/$APP_NAME/$APP_INSTANCE
~~~~~
Other variables you may use in your install scripts are NOT automagically set, but using this convention it would make things easier:
~~~~~
APP_IMG # Full Docker Image (including URL of Docker Reg) to use in your app install
APP_DATA_DIR # If there are specific directories for your app (1, 2, 3 etc)
APP_X_PORT # If it uses a certain port, sometime I just use APP_PORT other times I use APP_SSH_PORT or other identifier
APP_CPU and APP_MEM # settings for submit in Marathon etc.
~~~~~


