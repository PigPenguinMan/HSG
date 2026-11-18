from PIL import Image
import sys
PAL = {
 '.':(0,0,0,0), 'O':(30,22,34,255),
 'd':(104,108,128,255), 'g':(148,153,172,255), 'G':(186,190,205,255),
 'w':(244,234,222,255), 'W':(222,208,196,255), 'p':(222,150,158,255), 'c':(232,142,150,255),
 'e':(30,22,34,255),
 's':(186,44,60,255), 'S':(130,28,46,255),
 'k':(72,62,90,255), 'K':(52,44,66,255),
 'b':(60,48,44,255), 'x':(0,0,0,64),
}
# left half (x0..15); mirrored to 32 wide. Feet sit on row 26.
L = [
"................",
"................",
"................",
"................",
"................",
"........O.......",
"........OO......",
".......OdgO.....",
".......OgpO.....",
".......OgpgOOOOO",
".......Ogggggggg",
".......Ogggggggg",
".......Ogwwwwwgg",
".......Ogwewwwwg",
".......Ogwewwwww",
"......Oggcwwwwwe",
"......OOgwwwwwww",
".......OOOSsssss",
"........OSSsssss",
".........OkkkkOw",
"........OgOkkkkk",
"........OgOkkkkk",
"........OOOkkkkk",
".........OKkkkkk",
"..........OKKKKK",
"...........ObbO.",
"...........OOOO.",
"..........xxxxxx",
"................",
"................",
"................",
"................",
]
LEG_TOP=25
def mirror(rows):
    return [list(r+r[::-1]) for r in rows]
A=mirror(L)
for x,y,c in [(24,20,'O'),(25,20,'O'),(23,21,'O'),(24,21,'g'),(25,21,'g'),(26,21,'O'),
              (23,22,'O'),(24,22,'g'),(25,22,'w'),(26,22,'w'),(27,22,'O'),
              (24,23,'O'),(25,23,'O'),(26,23,'O')]:
    A[y][x]=c
def frameB(A):
    B=[r[:] for r in A]
    for y in range(LEG_TOP-1,0,-1): B[y]=A[y-1][:]
    B[0]=['.']*32
    for y in (LEG_TOP,LEG_TOP+1,LEG_TOP+2): B[y]=A[y][:]
    # lift left foot
    for x in (11,12,13,14): B[LEG_TOP+1][x]='.'
    B[LEG_TOP][11]='O';B[LEG_TOP][12]='O';B[LEG_TOP][13]='O';B[LEG_TOP][14]='O'
    return B
def img(g):
    im=Image.new('RGBA',(32,32))
    for y,row in enumerate(g):
        for x,ch in enumerate(row): im.putpixel((x,y),PAL[ch])
    return im
sheet=Image.new('RGBA',(64,32)); sheet.paste(img(A),(0,0)); sheet.paste(img(frameB(A)),(32,0))
sheet.save(sys.argv[1])
