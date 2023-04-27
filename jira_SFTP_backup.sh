#!/bin/bash

set -e
set -x

export key_of_ccryptkey="/root/backup_script/key.txt"
export date_regex=""$(date +"%Y-%m-%d-%H-%M-%S")
export global_jira_backup_dir="/var/backups/jira-backups"
export daily_backup_dir="$global_jira_backup_dir/daily"
export weekly_backup_dir="$global_jira_backup_dir/weekly"
export monthly_backup_dir="$global_jira_backup_dir/monthly"
export log_dir="$global_jira_backup_dir/log"
export specific_backup_dir="$global_jira_backup_dir/$date_regex"
export jira_db_docker_volume_backup_dir="$specific_backup_dir/jira_db_docker_volume"

main() {
        create_key_for_encrypt
        create_specific_backup_dir_and_log_dir
        create_timely_backup_dir
        get_backup_from_jira_files
        create_sub_dir_and_get_backup_from_jiradb
        tar_specific_backup_dir_then_encrypt
        remove_specific_backup_dir
        move_tar_backup_file_to_timely_dirs
        remove_first_tar_backup_file
        send_daily_file_to_sftp_server
        send_weekly_file_to_sftp_server
        send_monthly_file_to_sftp_server
        removing_local_files_older_than_seven_days_from_daily_dir
        removing_local_files_older_than_five_weeks_from_weekly_dir
        removing_local_files_older_than_five_months_from_monthly_dir
        remove_first_character_from_log_files
        removing_remote_files_older_than_seven_days_from_sftp_daily_dir
        removing_remote_files_older_than_five_weeks_from_sftp_weekly_dir
        removing_remote_files_older_than_five_months_from_sftp_monthly_dir
        check_backup_file_size_and_send_notification_mail
}

create_key_for_encrypt () {
        echo "your_password_for_encryption" > $key_of_ccryptkey
}

create_specific_backup_dir_and_log_dir() {
        mkdir -p $specific_backup_dir
        mkdir -p $log_dir
}

create_timely_backup_dir() {
        mkdir -p $daily_backup_dir
        mkdir -p $weekly_backup_dir
        mkdir -p $monthly_backup_dir
}

get_backup_from_jira_files() {
        cp -r /root/jira/ "$specific_backup_dir/"
}

create_sub_dir_and_get_backup_from_jiradb() {
        mkdir -p "$jira_db_docker_volume_backup_dir"
        cp -r /var/lib/docker/volumes/jira_postgresqldata "$jira_db_docker_volume_backup_dir/"
}

tar_specific_backup_dir_then_encrypt() {
        tar -czvf "$global_jira_backup_dir/$date_regex-jira.tar.gz" $specific_backup_dir
        pushd $global_jira_backup_dir/
        ccrypt -e -k $key_of_ccryptkey "$date_regex-jira.tar.gz"
        popd
}

remove_specific_backup_dir() {
        rm -rf $specific_backup_dir
}

move_tar_backup_file_to_timely_dirs() {
        cp "$global_jira_backup_dir/$date_regex-jira.tar.gz.cpt" $daily_backup_dir/
        if [[ $(date +%u) -eq 6 ]]; then
                cp "$global_jira_backup_dir/$date_regex-jira.tar.gz.cpt" $weekly_backup_dir/
        fi
        if [[ $(date +%d) -eq 29 ]]; then
                cp "$global_jira_backup_dir/$date_regex-jira.tar.gz.cpt" $monthly_backup_dir/
        fi
}

remove_first_tar_backup_file() {
        rm -rf "$global_jira_backup_dir/$date_regex-jira.tar.gz.cpt"
}

send_daily_file_to_sftp_server() {
        sudo sshpass -p 'your_sftp_password' sftp your_sftp_server:your_sftp_location <<< "put $daily_backup_dir/$date_regex-jira.tar.gz.cpt"
}

send_weekly_file_to_sftp_server() {
        if [[ $(date +%u) -eq 6 ]]; then
                sudo sshpass -p 'your_sftp_password' sftp your_sftp_server:your_sftp_location <<< "put $weekly_backup_dir/$date_regex-jira.tar.gz.cpt"
        fi
}

send_monthly_file_to_sftp_server() {
        if [[ $(date +%d) -eq 29 ]]; then
                sudo sshpass -p 'your_sftp_password' sftp your_sftp_server:your_sftp_location <<< "put $monthly_backup_dir/$date_regex-jira.tar.gz.cpt"
        fi
}

removing_local_files_older_than_seven_days_from_daily_dir() {
        find  $daily_backup_dir/ -type f -mtime +7 -name '*.gz.cpt' > $log_dir/daily_must_be_remove.log
        find  $daily_backup_dir/ -type f -mtime +7 -name '*.gz.cpt' -print0 | xargs -r0 rm --
}

removing_local_files_older_than_five_weeks_from_weekly_dir() {
        find  $weekly_backup_dir/ -type f -mtime +35 -name '*.gz.cpt' > $log_dir/weekly_must_be_remove.log
        find  $weekly_backup_dir/ -type f -mtime +35 -name '*.gz.cpt' -print0 | xargs -r0 rm --
}

removing_local_files_older_than_five_months_from_monthly_dir() {
        find  $monthly_backup_dir/ -type f -mtime +150 -name '*.gz.cpt' > $log_dir/monthly_must_be_remove.log
        find  $monthly_backup_dir/ -type f -mtime +150 -name '*.gz.cpt' -print0 | xargs -r0 rm --
}

remove_first_character_from_log_files() {
        sed -i 's/^..//' $log_dir/daily_must_be_remove.log
        sed -i 's/^..//' $log_dir/weekly_must_be_remove.log
        sed -i 's/^..//' $log_dir/monthly_must_be_remove.log
}

removing_remote_files_older_than_seven_days_from_sftp_daily_dir(){
        while read line; do
                sudo sshpass -p 'your_sftp_password' sftp your_sftp_server:your_sftp_location <<< "rm $line"
        done < $log_dir/daily_must_be_remove.log
}

removing_remote_files_older_than_five_weeks_from_sftp_weekly_dir(){
        while read line; do
                sudo sshpass -p 'your_sftp_password' sftp your_sftp_server:your_sftp_location <<< "rm $line"
        done < $log_dir/weekly_must_be_remove.log
}

removing_remote_files_older_than_five_months_from_sftp_monthly_dir(){
        while read line; do
                sudo sshpass -p 'your_sftp_password' sftp your_sftp_server:your_sftp_location <<< "rm $line"
        done < $log_dir/monthly_must_be_remove.log
}

check_backup_file_size_and_send_notification_mail() {
        minimumsize=50000
        actualsize=$(du -k "$daily_backup_dir/$date_regex-jira.tar.gz.cpt" | cut -f 1)
        if [ $actualsize -ge $minimumsize ]; then
                echo "about jira ; backup was successful ; size of backup file is : $(echo $actualsize ) kilobytes ; name of backup file is : $(echo $date_regex-jira.tar.gz.cpt)" | mail -s "jira backup" your_email_address
        else
                echo "about jira ; backup was not successful ; size of backup file is : $(echo $actualsize ) kilobytes " | mail -s "jira backup" your_email_address
        fi
}

main
