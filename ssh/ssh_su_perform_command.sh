./establish_ssh_setup.sh $1
ssh -t admin@$1 'sudo -k; printf "HeWGEUx66m=_4!ND\n" | sudo -S su ; sudo $2'
