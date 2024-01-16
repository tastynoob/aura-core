import re



debugFlag_pipeline_re = r"\d+ DebugFlag-PIPELINE: \[sn (\d+) pc ([\da-zA-Z]+)\] ([a-zA-z]+) F(\d+) ([\d:]+C)"

debugFlag_pipeline_pattern = re.compile(debugFlag_pipeline_re)


def printPipe(res):
    stage = ['f', 'd', 'r', 'D', 'i', 'e', 'c']
    sn, pc, disass, ftime, pipe = res
    i = 0
    line = ['.'] * 100
    ti = int(ftime)
    for c in pipe.split(':'):
        if c != 'C':
            c = int(c)
            s = stage[i]
            for j in range(c):
                line[ti % 100] = s
                ti+=1
        else :
            line[ti % 100] = 'C'
        i+=1
    print('[' + ''.join(line) + ']', '[sn %s pc %s]' % (sn, pc), disass)

    


def fparser(file):
    fs = open(file, 'r')
    for line in fs.readlines():
        line = line.strip()
        if 'DebugFlag-PIPELINE' in line:
            res = debugFlag_pipeline_pattern.findall(line)[0]
            printPipe(res)
            

fparser('/home/lurker/workspace/O3CPU/aura-core/log.txt')


