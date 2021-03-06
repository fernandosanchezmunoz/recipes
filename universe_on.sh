#PREREQUISITES
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install -y epel-release
yum install -y git python-pip python34 jq nginx
curl https://bootstrap.pypa.io/get-pip.py | python3.4
pip3 install --upgrade pip jsonschema
# upgrade python to 3.6+ for latest universe
sudo yum -y install https://centos7.iuscommunity.org/ius-release.rpm
sudo yum -y install python36u python36u-pip
sudo mv /bin/python3 /bin/python3.bak.3-4
sudo ln -s /usr/bin/python3.6 /bin/python3
sudo mv /bin/pyenv /bin/pyenv.bak.3-4
sudo ln -s /bin/pyenv-3.6 /bin/pyenv
sudo mv /bin/pydoc3 /bin/pydoc3.bak-3.4
ln -s /bin/pydoc-3.6 /bin/pydoc3
#####################
BASEDIR=~
GITHUB_USER=mesosphere
REPONAME=universe
PACKAGENAME="version-3.x"
BACKEND_PACKAGE=""
SERVERIP=$(ip addr show eth0 | grep -Eo \
 '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1) #this node's eth0
SERVERPORT=8085

########################################
# BOOTSTRAP NODE: create from scratch after code change
########################################
cd $BASEDIR
rm -Rf $REPONAME
git clone -b $PACKAGENAME http://github.com/$GITHUB_USER/$REPONAME
cd $REPONAME

scripts/build.sh

#build image and marathon.json
DOCKER_TAG=$PACKAGENAME docker/server/build.bash

#run the docker image in the bootstrap node
docker run -d --name universe-dev -p $SERVERPORT:80 mesosphere/universe-server:$PACKAGENAME

#OPTIONAL: save image for exporting the repo
docker save -o $BASEDIR/$REPONAME/$REPONAME$PACKAGENAME.tar mesosphere/universe-server:$PACKAGENAME

#add repo from the universe we just started
dcos package repo add --index=0 dev-universe http://$SERVERIP:$SERVERPORT/repo

#check that the universe is running -- FROM THE BOOTSTRAP OR ANY NODE
#curl http://$SERVERIP:8085/repo | grep $PACKAGENAME

dcos package install --yes $BACKEND_PACKAGE
dcos package install --yes $PACKAGENAME
dcos package install --yes $PACKAGENAME-admin

echo -e "Copy and paste the following into each node of the cluster to activate this server's certificate on them:"
echo -e "mkdir -p /etc/docker/certs.d/$SERVERIP:5000"
echo -e "curl -o /etc/docker/certs.d/$SERVERIP:5000/ca.crt http://$SERVERIP:$SERVERPORT/certs/domain.crt"
echo -e "systemctl restart docker"
echo -e ""
