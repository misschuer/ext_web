eval `ssh-agent`
ssh-add ../net
cd conf
# 提交版本
git add .
git commit -am 'public version'
git push net master
