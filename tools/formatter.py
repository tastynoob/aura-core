import os

svfiles = []
def get_svfiles(path):
    global svfiles
    subfolders = os.listdir(path)
    for i in subfolders:
        subpath = os.path.join(path,i)
        if os.path.isdir(subpath):
            get_svfiles(subpath)
        if os.path.isfile(subpath):
            if subpath.endswith('.sv') or subpath.endswith('.svh'):
                svfiles.append(subpath)

def is_modified(file):
    return os.system('git diff --quiet ' + file) != 0


aura_home = os.environ.get('AURA_HOME')
rtlpath = (aura_home + '/' if aura_home else '') + 'rtl'
get_svfiles(rtlpath)


formatCommand = 'verible-verilog-format --flagfile .sv.format --inplace'
for svfile in svfiles:
    if is_modified(svfile):
        command = formatCommand + ' ' + svfile
        print(command)
        os.system(command)

