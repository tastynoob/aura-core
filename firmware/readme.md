# isa说明
当前目录下是vscode EIDE插件的工程项目   
同时也是ritter-soc的驱动项目    
如果需要使用    
请安装EIDE插件，然后打开此vscode项目

# 重要事项说明

BintoMem.py是将编译好的二进制文件转为ritter-soc可使用的bram填充文件     
其中mem.dat即为转换好的文件     
在ritter-soc编译时,请修改/project/al_ip/bram_itcm.v中的填充文件地址     
否则ritter-soc将无法运行你的程序        
同时也不用担心编译一次程序就需要重编译一次ritter-soc        
安路TD软件提供了在线更新bram的功能      
只需打开TD软件的烧录功能        
选择"update bram data"即可


# bootloader说明

目前ritter-soc已经支持bootloader,bootloader存放在内存地址60k处      
bootloader代码位于bootloader/文件夹下       
bootloader.bin是已经编译好的bootloader代码      
flasher.py是用来烧录bootloader的脚本,可以使用串口更新内部程序     
注意:FPGA重置会导致ITCM重置,但是可以通过"user"按钮重新执行用户程序            
目前暂不支持将程序写入flash中保存       



