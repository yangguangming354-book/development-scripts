# development-scripts

本地目录：C:\Users\yangc\Documents\ChatGPT\开发
GitHub账号：yangguangming354-book
仓库名称：development-scripts
远程地址：https://github.com/yangguangming354-book/development-scripts.git
Git提交作者：yangchuanwu
Git提交邮箱：yangguangming354@gmail.com
默认分支：main

## 内网地址探测

默认扫描 `172.23.80.0/24`：

```powershell
python .\network_scan.py
```

扫描其他网段或调整参数：

```powershell
python .\network_scan.py 192.168.1.0/24 --timeout 1000 --workers 32
```
