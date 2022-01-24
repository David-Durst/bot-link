script_dir="tmp"
#https://www.ostricher.com/2014/10/the-right-way-to-get-the-directory-of-a-bash-script/
get_script_dir () {
     SOURCE="${BASH_SOURCE[0]}"
     # While $SOURCE is a symlink, resolve it
     while [ -h "$SOURCE" ]; do
          DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
          SOURCE="$( readlink "$SOURCE" )"
          # If $SOURCE was a relative symlink (so no "/" as prefix, need to resolve it relative to the symlink base directory
          [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
     done
     DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
     script_dir="$DIR"
}
get_script_dir
mkdir -p compiled/bot-link
if ./compile.sh bot-link/$1.sp; then
	cp compiled/bot-link/$1.smx ../plugins/
    if [ -f ${script_dir}/rcon.json ] && [  -x "$(command -v csgo-rcon)" ]; then
        csgo-rcon -c ${script_dir}/rcon.json "sm_rcon sm plugins unload $1; sm_rcon sm plugins load $1"
    else
        ${script_dir}/reminder.sh $1
    fi
fi

data_path=/home/steam/csgo-ds/csgo/addons/sourcemod/scripting
mkdir -p $data_path
chmod 777 $data_path
