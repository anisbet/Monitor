# Monitor
Monitors a given process and sends an email if it is not running.
An email will be sent once a day while the target application is not found to be running.

## Flags

- -a, -app, --app="bar.sh fizz.sh": Specifies the application(s) to monitor.
- -e, -email, --email="user@example.com customer@example.com": Specifies the email addressees.
- -h, -help, --help: This help message.
- -t, -test, --test: Display debug information to STDOUT.
- -v, -version, --version: Print watcher.sh version and exits.
