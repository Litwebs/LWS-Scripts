reset rsa key



1.Remove only the offending key (recommended)

**ssh-keygen -R 87.106.101.195**



2.Add key if already exists

or

Generate new key

**ssh-keygen -t ed25519**





3\.

MAC
**ssh-copy-id -i ~/.ssh/id\_rsa.pub root@87.106.101.195**



Windows

**type $env:USERPROFILE\\.ssh\\id\_rsa.pub | ssh root@87.106.101.195 "mkdir -p ~/.ssh \&\& cat >> ~/.ssh/authorized\_keys \&\& chmod 600 ~/.ssh/authorized\_keys \&\& chmod 700 ~/.ssh"**



Are you sure you want to continue connecting (yes/no/\[fingerprint])? **yes**









