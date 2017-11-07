sshpass -f /home/omargaliot/passwords/BS.txt ssh -o StrictHostKeyChecking=no admin@$1 rm .ssh/authorized_keys
sshpass -f /home/omargaliot/passwords/BS.txt ssh-copy-id admin@$1
