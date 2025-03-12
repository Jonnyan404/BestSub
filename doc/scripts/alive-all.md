# 使用说明

alive-all 包含测速通过和测速不通过但存活的所有节点,仅适用于docker镜像. 其它方式运行,请注意自行调整脚本.

1. 下载脚本文件到`output`目录下
```bash
wget "https://raw.githubusercontent.com/Jonnyan404/BestSub/refs/heads/master/doc/scripts/alive-all.sh"
wget "https://raw.githubusercontent.com/Jonnyan404/BestSub/refs/heads/master/doc/scripts/upload.sh"
chmod 666 alive-all.sh upload.sh
```

2. 在 `config.yaml` 文件中增加下列配置
```yaml
省略前面配置
save:                                                                                                        
  # Save method: webdav, http, gist, or r2                                                                   
  method:                                                                                                    
    - gist                                                                                                   
    - local                                                                                                  
  before-save-do:                                                                                            
    - /app/output/alive-all.sh                                                                               
  after-save-do:                                                                                             
    - /app/output/upload.sh /app/output/alive-all.yaml gist "update node"    # 目前支持gist/webdav/all/none参数,gist和webdav均调用的config.yaml文件中的相关参数,如有上传需求,请注意配置相关参数.                   
  # Save port                                                                                                
  port: 8080
省略后面配置
```

3. 重启容器生效
