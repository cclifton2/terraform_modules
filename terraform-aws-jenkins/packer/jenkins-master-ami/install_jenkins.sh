sudo yum -y update

sudo yum install -y java-1.8.0-openjdk.x86_64

sudo /usr/sbin/alternatives --set java /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/java

sudo /usr/sbin/alternatives --set javac /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/javac

sudo yum remove -y java-1.7*

# install core reqs plus nginx for ssl termination
sudo yum install -y git nginx aws-cli
sudo update-alternatives --config java

# install maven
sudo wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo
sudo sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo
sudo yum install -y apache-maven
#mvn –v

# install xmlstarlet used for XML config manipulation
sudo yum install -y xmlstarlet

# install jenkins
sudo wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo
sudo rpm --import http://pkg.jenkins-ci.org/redhat/jenkins-ci.org.key

# todo: parameterize version
sudo yum install -y jenkins