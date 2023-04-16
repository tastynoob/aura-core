import os 
import argparse

folders = ""
def get_list_of(path):
    global folders
    subfolders = os.listdir(path)
    for i in subfolders:
        subpath = os.path.join(path,i)
        if os.path.isdir(subpath):
            folders+=" -y " + subpath
            get_list_of(subpath)



parser = argparse.ArgumentParser()
parser.add_argument("-p", "--path", action="store",
                    help="the path which you want to list reduce")
args = parser.parse_args()
get_list_of(args.path)
print(folders,end='')
