#!/usr/bin/env python3

import sys
import os
import struct


def int2bin(n, count=32):
    """returns the binary of integer n, using count number of digits"""
    return "".join([str((n >> y) & 1) for y in range(count-1, -1, -1)])

def bin_to_mem(infile, outfile,outfile2):
    binfile = open(infile, 'rb')
    file_size = os.path.getsize(infile)
    print("File size: ", file_size)
    binfile_content = binfile.read(file_size)
    #"额外"的英文是 "extra"
    extra_data = b'\x00' * (64*1024-file_size)
    binfile_content += extra_data
    datafile = open(outfile, 'w')
    datafile2 = open(outfile2, 'w')
    datafile2.write('@0000\n')
    index = 0
    b0 = 0
    b1 = 0
    b2 = 0
    b3 = 0
    for b in  binfile_content:
        if index == 0:
            b0 = b
            index = index + 1
        elif index == 1:
            b1 = b
            index = index + 1
        elif index == 2:
            b2 = b
            index = index + 1
        elif index == 3:
            b3 = b
            index = 0
            array = []
            array.append(b3)
            array.append(b2)
            array.append(b1)
            array.append(b0)
            datafile.write(bytearray(array).hex() + '\n')
            num = struct.unpack(">I", bytearray(array))[0]
            #写入array的二进制值
            datafile2.write(int2bin(num) + '\n')
    binfile.close()
    datafile.close()
    datafile2.close()

    
    







bin_to_mem("build\\Debug\\tinymcu.bin", "mem.list","mem.dat")

