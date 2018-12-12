import sys
import os


def escape_and_write(outfile, c):
    if c == '<':
        outfile.write('&lt;')
    else:
        outfile.write(c)


def read_until_end_of_comment(infile, outfile):
    c =infile.read(1)
    if c == '-':
        # this is the second - character, start of a comment
        in_block_comment = False
        while c and (in_block_comment or not c == '\n'):
            prevC = c
            c = infile.read(1)
            if c == '[' and prevC == '[':
                in_block_comment = True
            if c == ']' and prevC == ']':
                in_block_comment = False
    else:
        # write the - which triggered this call
        escape_and_write(outfile, '-')
        # and write the character we read afterwards (non -)
        escape_and_write(outfile, c)


luaFile = sys.argv[1]
dirName = os.path.dirname(luaFile)

in_string = False
open_string = ''

with open(luaFile, mode='r') as infile, open('../reload.xml', 'w') as outfile:
    outfile.write('<code>')
    while True:
        c = infile.read(1)
        if not c:
            break
        if c == '"' or c == "'":
            if not in_string:
                open_string = c
                in_string = True
            elif open_string == c:
                in_string = False

        if c == '-' and not in_string:
            read_until_end_of_comment(infile, outfile)
        else:
            escape_and_write(outfile, c)

    outfile.write('</code>')
