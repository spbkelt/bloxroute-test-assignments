# Project Description
This repository provides an automated setup for integrating Fluentd with Nginx logs using Ansible. The solution dynamically filters logs based on a configurable IP denylist and forwards matched logs to a dedicated log file. It is ideal for developers and teams looking to enhance log processing efficiency in production environments.

## The setup handles:

- Installation and configuration of Fluentd.
- Dynamic IP filtering using a black list.
- Secure access control to Nginx log files for Fluentd.

## Project structure
```bash
ansible/
├── fluentd-playbook.yml
├── inventory.ini
└── roles
    └── fluentd
        ├── files
        │   └── denylist.txt
        └── templates
            └── fluentd.conf.j2
```

## Setup Instructions
### Prerequisites

Target Environment:

Ubuntu 22.04 or later.
Nginx installed and running with logs stored in /var/log/nginx/.
## Control Node Requirements:

Ansible 2.10+ installed on the control machine.

Installation guidelines are provided here: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html

Unpach the archive:
```bash
git clone https://github.com/spbkelt/bloxroute-test-assignments
cd Take_Home_Assignment_3
```

# Steps to Set Up Fluentd and Filter Logs
Update Inventory:
Define target hosts in the local inventory file:

```ini
[nginx_servers]
nginx-server ansible_host=<nginx-server-ip> ansible_user=ubuntu
```

## Configure Denylist:
Add IPs to filter in `ansible/roles/fluentd/files/denylist.txt`:

```bash
<insert-your-public-ip>
<some-arbitrary-ip>
```

## Run the Playbook:
Execute the following command to deploy Fluentd:

```bash
ansible-playbook -i inventory.ini fluentd-playbook.yml
```

## Service Verification:
After running the playbook, ensure Fluentd is running:

```bash
sudo systemctl status fluentd
```
## Testing the Setup:
- Generate test logs by accessing Nginx with an IP in the `ansible/roles/fluentd/files/denylist.txt`.
- Confirm those logs appear in the audit log.
- We assume that our public IP is already in denylist.txt

```bash
# Get our public IP
curl ifconfig.me
curl -v <nginx-server-ip>
```

## Verify Log Filtering:
Check the output log for filtered IPs in:

```bash
ssh -i <path-to-ssh-key> ubuntu@<nginx-server-ip>
sudo tail -5 /var/log/fluent/denylist_audit.log/buffer.*.log
2024-11-19T13:03:47+00:00	nginx.access	{"remote":"<your-public-ip>","host":"-","user":"-","method":"GET","path":"/","code":"304","size":"0","referer":"-","agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"}
2024-11-19T13:03:49+00:00	nginx.access	{"remote":"<your-public-ip>","host":"-","user":"-","method":"GET","path":"/","code":"304","size":"0","referer":"-","agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"}
2024-11-19T13:03:50+00:00	nginx.access	{"remote":"<your-public-ip>","host":"-","user":"-","method":"GET","path":"/","code":"304","size":"0","referer":"-","agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"}
2024-11-19T13:03:52+00:00	nginx.access	{"remote":"<your-public-ip>","host":"-","user":"-","method":"GET","path":"/","code":"304","size":"0","referer":"-","agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"}
2024-11-19T13:05:15+00:00	nginx.access	{"remote":"<your-public-ip>","host":"-","user":"-","method":"GET","path":"/","code":"304","size":"0","referer":"-","agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"}
```

# Solution: Log Rotation for Nginx Logs
To manage the size of the Nginx access logs and retain only the last 5 days' worth of data, we can use logrotate, a widely used tool for automated log rotation. This tool rotates, compresses, and deletes old log files according to a defined schedule.

### Implementation Steps
Install logrotate
Logrotate is pre-installed on most Linux systems. To ensure it is available:

```bash
sudo apt-get update -y
sudo apt-get install logrotate -y
```
### Create a Custom Logrotate Configuration
Add a configuration file specifically for Nginx logs:

```bash
sudo vim /etc/logrotate.d/nginx
```

Add the following configuration to the file:

```plaintext
/var/log/nginx/*.log {
    daily
    rotate 5
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
    endscript
}
```

### Explanation of Configuration:


- daily: Rotate the logs daily.
- rotate 5: Keep the last 5 rotated logs.
- compress: Compress old log files to save disk space.
- delaycompress: Postpone compression of the most recently rotated log until the next cycle.
- missingok: Skip the rotation if the log file is missing.
- notifempty: Skip rotation if the log file is empty.
- create: Recreate the log file after rotation with specified permissions.
- sharedscripts: Ensures postrotate script runs once, even for multiple log files.
- postrotate/endscript: Signal Nginx to reopen log files after rotation.

### Test the Configuration
Manually test the logrotate setup to ensure it behaves as expected:

```bash
sudo logrotate -vf /etc/logrotate.d/nginx
````

This command forces log rotation and provides verbose output for debugging.

### Automate with Cron
Logrotate is typically scheduled by default through a daily cron job. To confirm:

```bash
cat /etc/cron.daily/logrotate
```

If it’s not automated, add a cron entry to run logrotate daily:

```bash
sudo crontab -e
```

Add the line:

```bash
0 1 * * * /usr/sbin/logrotate /etc/logrotate.conf
```
### Integration with Fluentd
After implementing log rotation:

Fluentd will automatically detect the log files created by logrotate if you configure it to monitor /var/log/nginx/*.log dynamically.
Ensure Fluentd uses a pos_file for each rotated log file to avoid duplicating log entries.
Example Fluentd configuration:

```plaintext
<source>
  @type tail
  path /var/log/nginx/*.log
  pos_file /var/log/fluentd/nginx.pos
  tag nginx.access
  format nginx
</source>
```

This solution ensures that Nginx logs are efficiently managed, disk usage is controlled, and Fluentd continues to process logs seamlessly. Let me know if you'd like further details or additional enhancements!












