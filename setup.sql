CREATE USER IF NOT EXISTS 'machine_user'@'localhost' IDENTIFIED BY 'machine_password';
GRANT ALL PRIVILEGES ON machine_monitoring.* TO 'machine_user'@'localhost';
FLUSH PRIVILEGES;
