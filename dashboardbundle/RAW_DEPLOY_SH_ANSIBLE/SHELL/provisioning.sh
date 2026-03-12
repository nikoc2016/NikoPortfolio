#!/bin/bash
echo {AWS-TOKENNAME}:{AWS-SECRET} > ${HOME}/.passwd-s3fs
# Set up environment variables
echo "Setting up environment variables..."
PROJ_DIR="$HOME/project"
DATA_DIR="$PROJ_DIR/data"
BIN_DIR="$PROJ_DIR/bin"
S3_DIR="/mnt/s3"
PROV_FILES_DIR="$PROJ_DIR/provfiles"
PROV_FILES_TAR="provision_files_v1.tar.gz"
MYSQL_SCRIPT_DIR="$PROV_FILES_DIR/initdb_scripts"
MYSQL_ROOT_PASSWD="root"
MYSQL_EXP_USER="exporter"
MYSQL_EXP_PASSWD="password"
MYSQL_DATA_DIR="$DATA_DIR/mysql_data"
MYSQL_EXP_DIR="$PROV_FILES_DIR/mysql_exporter"
MYSQL_EXP_CONF_PATH="$MYSQL_EXP_DIR/.my.cnf"
REDIS_CONF_DIR="$PROV_FILES_DIR/redis_config"
REDIS_CONF_FILE="redis.conf"
REDIS_DATA_DIR="$DATA_DIR/redis_data"
PROM_SRC_DIR="$BIN_DIR/prometheus"
PROM_BIN_DIR="$BIN_DIR/prometheus_bin"

# Prepare S3 bucket connection
echo "Preparing S3 bucket connection..."
sudo apt-get update
sudo apt-get install s3fs -y
echo "Configuring S3FS..."
chmod 600 ${HOME}/.passwd-s3fs
sudo mkdir -p $S3_DIR
echo "Adding S3FS to fstab..."
echo "s3fs#prometheus-spacec $S3_DIR fuse _netdev,passwd_file=${HOME}/.passwd-s3fs,url=https://s3.us-west-1.amazonaws.com,use_path_request_style,allow_other,umask=000 0 0" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
sudo mount -a

# Prepare provisioning files
echo "Extracting provisioning files..."
mkdir -p $PROV_FILES_DIR
tar -xzvf $S3_DIR/bin/$PROV_FILES_TAR -C $PROV_FILES_DIR

# Install Docker
echo "Installing Docker..."
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "Configuring Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
echo "Installing Docker packages..."
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
echo "Adding user to Docker group..."
sudo usermod -aG docker $(whoami)
echo "Creating Docker network 'monitor_net'..."
sudo docker network create monitor_net

# Prepare & Run MySQL
echo "Installing MySQL client..."
sudo apt-get install mysql-client -y
echo "Setting up MySQL initialization scripts..."
mkdir -p $MYSQL_SCRIPT_DIR
sudo tee "$MYSQL_SCRIPT_DIR/init.sql" > /dev/null << EOF
CREATE USER '$MYSQL_EXP_USER'@'%' IDENTIFIED BY '$MYSQL_EXP_PASSWD';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '$MYSQL_EXP_USER'@'%';
FLUSH PRIVILEGES;
EOF
echo "Running MySQL Docker container..."
sudo docker run -d \
  --name mysql8 \
  --restart always \
  --network monitor_net \
  -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWD \
  -e MYSQL_DATABASE=project \
  -p 3306:3306 \
  -v $MYSQL_DATA_DIR:/var/lib/mysql \
  -v $PROV_FILES_DIR/initdb_scripts/:/docker-entrypoint-initdb.d/ \
  mysql:8.0.33

# Prepare & Run MySQL Exporter
echo "Setting up MySQL exporter..."
mkdir -p $MYSQL_EXP_DIR
sudo tee "$MYSQL_EXP_CONF_PATH" > /dev/null << EOF
[client]
host=mysql8
port=3306
user=$MYSQL_EXP_USER
password=$MYSQL_EXP_PASSWD
EOF
echo "Running MySQL Exporter Docker container..."
sudo docker run -d \
  -p 9104:9104 \
  -v $MYSQL_EXP_CONF_PATH:/cfg/.my.cnf \
  --name mysql-exporter \
  --restart always \
  --network monitor_net \
  prom/mysqld-exporter \
  --config.my-cnf=/cfg/.my.cnf \
  --collect.global_status \
  --collect.info_schema.innodb_metrics \
  --collect.auto_increment.columns \
  --collect.info_schema.processlist \
  --collect.binlog_size \
  --collect.info_schema.tablestats \
  --collect.global_variables \
  --collect.info_schema.query_response_time \
  --collect.info_schema.userstats \
  --collect.info_schema.tables \
  --collect.perf_schema.tablelocks \
  --collect.perf_schema.file_events \
  --collect.perf_schema.eventswaits \
  --collect.perf_schema.indexiowaits \
  --collect.perf_schema.tableiowaits \
  --collect.slave_status

# Prepare & Run Redis
echo "Installing Redis tools..."
sudo apt-get install redis-tools -y
echo "Setting up Redis configuration..."
mkdir -p $REDIS_CONF_DIR
sudo tee "$REDIS_CONF_DIR/$REDIS_CONF_FILE" > /dev/null <<EOF
port 6379
bind 0.0.0.0
requirepass password
EOF
echo "Running Redis Docker container..."
sudo docker run -d \
  --name redis7 \
  --restart always \
  --network monitor_net \
  -p 6379:6379 \
  -v $REDIS_DATA_DIR:/data \
  -v $REDIS_CONF_DIR/:/etc/redis/ \
  redis:7.2.5 \
  /etc/redis/$REDIS_CONF_FILE

# Download binaries
echo "Downloading binaries..."
mkdir -p $BIN_DIR

# NodeExporter
echo "Setting up Node Exporter..."
APP="node_exporter-1.8.1.linux-amd64"
TYPE=".tar.gz"
ALIAS="node_exporter"
EXE="node_exporter"
tar -xzvf $PROV_FILES_DIR/$APP$TYPE -C $BIN_DIR

sudo tee "/etc/systemd/system/$ALIAS.service" > /dev/null <<EOF
[Unit]
Description=$ALIAS
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=$BIN_DIR/$APP/$EXE --web.listen-address=:9100 --collector.disable-defaults --collector.cpu --collector.loadavg --collector.xfs --collector.meminfo --collector.filesystem --collector.diskstats --collector.uname --collector.vmstat --collector.filesystem.fs-types-exclude="^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|tmpfs|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs)$" --collector.netdev --collector.stat --collector.tcpstat --collector.processes --collector.diskstats.device-exclude="^(ram|loop|fd|(h|s|v|xv)d[a-z]|nvmed+nd+p)d+$"
WorkingDirectory=$BIN_DIR/$APP/
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
echo "Starting and enabling Node Exporter service..."
sudo systemctl daemon-reload
sudo systemctl restart $ALIAS
sudo systemctl enable $ALIAS --now

# Compile and Test Prometheus
echo "Installing Golang and other dependencies..."
sudo apt-get install golang-go make npm nodejs -y
echo "Compiling Prometheus from source..."
mkdir -p $PROM_BIN_DIR
cd $BIN_DIR
git clone https://github.com/nikoc2016/prometheus.git
cd $PROM_SRC_DIR
make build
echo "Copying Prometheus binaries..."
cp -r $PROM_SRC_DIR/console_libraries $PROM_SRC_DIR/consoles $PROM_SRC_DIR/promtool $PROM_SRC_DIR/prometheus $PROM_BIN_DIR/
sudo rm -rf $PROM_SRC_DIR
sudo tee "$PROM_BIN_DIR/prometheus.yml" > /dev/null <<EOF
global:
  scrape_interval: 15s  # How often to scrape targets by default
  evaluation_interval: 15s  # How often to evaluate rules

scrape_configs:
  - job_name: 'mysql'
    static_configs:
      - targets: ['localhost:9104']
  
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
EOF

ALIAS="prometheus"
EXE="prometheus"
sudo tee "/etc/systemd/system/$ALIAS.service" > /dev/null <<EOF
[Unit]
Description=$ALIAS
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=$PROM_BIN_DIR/$EXE
WorkingDirectory=$PROM_BIN_DIR
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
echo "Starting and enabling Prometheus service..."
sudo systemctl daemon-reload
sudo systemctl restart prometheus
sudo systemctl enable prometheus --now

# Grafana
echo "Setting up Grafana..."
APP="grafana-11.0.0.linux-amd64"
TYPE=".tar.gz"
ALIAS="grafana"
EXE="bin/grafana server"
UNZIP_FOLDER="grafana-v11.0.0"
CONFIG_DIR="$PROV_FILES_DIR/grafana_config"
tar -xzvf $PROV_FILES_DIR/$APP$TYPE -C $BIN_DIR

sudo tee "/etc/systemd/system/$ALIAS.service" > /dev/null <<EOF
[Unit]
Description=$ALIAS
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=$BIN_DIR/$UNZIP_FOLDER/$EXE
WorkingDirectory=$BIN_DIR/$UNZIP_FOLDER/
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "Restoring Grafana configuration and starting the service..."
cp -r $CONFIG_DIR/* $BIN_DIR/$UNZIP_FOLDER

sudo systemctl daemon-reload
sudo systemctl restart grafana
sudo systemctl enable grafana --now

echo "Provisioning script completed successfully."
# DEMO
# mysqlslap --user=root --password=root --host=127.0.0.1 --concurrency=50 --iterations=10000 --query="SELECT * FROM employees;" --create-schema=classicmodels
# redis-benchmark -h 127.0.0.1 -p 6379 -c 100 -a password -n 100000