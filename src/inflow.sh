#!/bin/sh

COLOR=${COLOR:-0}

function info {
    [ $COLOR -eq 1 ] &&
    green="\033[0;32m" &&
    bold="\033[1m" &&
    reset="\033[0m"
    echo "${bold}[INFO]${reset} ${green}$1${reset}"
    return 0
}

function warning {
    [ $COLOR -eq 1 ] &&
    yellow="\033[1;33m" &&
    bold="\033[1m" &&
    reset="\033[0m"
    echo "${bold}[WARNING]${reset} ${yellow}$1${reset}"
    return 1
}

function warning_cont {
    [ $COLOR -eq 1 ] &&
    yellow="\033[1;33m" &&
    bold="\033[1m" &&
    reset="\033[0m"
    echo "${bold}[WARNING]${reset} ${yellow}$1${reset}"
    return 0
}

function error {
    [ $COLOR -eq 1 ] &&
    red="\033[0;31m" &&
    bold="\033[1m" &&
    reset="\033[0m"
    echo "${bold}[ERROR]${reset} ${red}$1${reset}"
    exit 1
}

function bucket_exists {
    influx bucket list --org "$1" --json |jq -e ".[] |select(.name==\"$2\")" 1> /dev/null
}

function bucket_id_by_name {
    echo $(influx bucket list --org "$1" --json |jq -r ".[] |select(.name==\"$2\") | .id")
}

function get_acl {
    echo $(yq -j e .users "$1" | jq -r ".[] | select(.name == \"$2\") | .$3 | @tsv" 2> /dev/null)
}

function user_exists {
    influx v1 auth list --json | jq -e ".[] |select(.token==\"$1\")" 1> /dev/null
}

function add_v1_user() {
    cnf=$1
    name=$2
    pass=$3
    org=$4

    read_buckets=""
    for bucket_name in $(get_acl "$cnf" "$name" "read"); do
        bucket_exists "$org" "$bucket_name" &&
            read_buckets="$read_buckets --read-bucket $(bucket_id_by_name $org $bucket_name)"
    done

    write_buckets=""
    for bucket_name in $(get_acl "$cnf" "$name" "write"); do
        bucket_exists "$org" "$bucket_name" &&
            write_buckets="$write_buckets --write-bucket $(bucket_id_by_name $org $bucket_name)"
    done

    user_exists $name && warning_cont "User $name already exists" && return 1

    ([ -n "$read_buckets" ] || [ -n "$write_buckets" ]) && 
        info "Creating user $name" &&
        influx v1 auth create --org "$org" --username "$name" --password "$pass" $read_buckets $write_buckets ||
        warning "No bukcets for the $name user"
}

CONFIG=$1
[ -f "$CONFIG" ] || error "The $CONFIG file does not exist."

ORG=`yq -e e '.org' $CONFIG` || error "The $CONFIG file does not set the organization."
info "Organization: $ORG"

info "Creating buckets"
yq -j e .buckets "$CONFIG" | jq -r '.[] | [.name, .retention, .description] | @tsv' |
while IFS=$'\t' read -r name retention description; do
    [ -n "$name" ] || warning "The bucket does not have a name" && bucket_exists $ORG $name &&
        info "Bukcet $name already exists, try to update it" &&
        influx bucket update --id "$(bucket_id_by_name $ORG $name)" --name "$name" --retention "${retention:-0}" --description "${description:-''}" ||
        (info "Creating bucket with name $name" &&
        influx bucket create --org "$ORG" --name "$name" --retention "${retention:-0}" --description "${description:-''}")
done

info "Creating users"
yq -j e .users "$CONFIG" | jq -r '.[] | [.name, .password] | @tsv' |
while IFS=$'\t' read -r name password; do
    [ -n "$name" ] || warning "A user does not have a name" &&
        [ -n "$password" ] || warning "User $name does not have a password" &&
        add_v1_user "$CONFIG" "$name" "$password" "$ORG"
done
exit 0
