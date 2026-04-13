/* bin2trd - Binary & Hobeta files to TRD (c)1999, Copper Feet */
/* 2002 - Modified for Linux by Alexander Shabarshin <me@shaos.net> */
/* 2018 - Translated to English by Shaos */
/* 2021 - Sprinter version by Dmitry Mikhaltchenkov <mikhaltchenkov@gmail.com> */

#include <stdio.h>
#include <malloc.h>
#include <io.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <dos.h>
//#include <fcntl.h>
#ifdef linux
#include <unistd.h>
#endif
#ifndef O_BINARY
#define O_BINARY 0
#endif

int HO,HI;

char Fname[80];
char LISTname[80];
char TRDname[80]; 

char tr0[0x800]; /* file table tr-dos */
char sec9[256]; /* 9th sector */
#define DNAME sec9+0xF5
char *pt,*ppt; /* pointers in text file */
char *pt_line;
/* parameters of current file */
char TRDOSname[9]; /* name of tr-dos file */
char ftyp; /* type */
unsigned fstart; /* start address */
unsigned blk; /* file length in 256 blocks */
struct fpoint *flenStruct; /* real file length - structure */
unsigned int flen; /* real file length */
int _tr,_sec; /* temportary track, sector */

/* Size of buffer for read/write operations */
#define BUFF_SIZE 4096

#define MAXSEC 2560
int asec; /* absolute sector (starting with trk0, sid0, sec0) */
int Nfile; /* number of files */
int freesec; /* number of free sectors */
int Line; /* processing line of file */
int TRUNC; /* 0/1 - standard truncated TRD */
int PASS_N; /* 0/1 - pass number */
int isHEAD; /* header TRD presented? */
int nnn; /* for get_string - string length */

int fTRUNC = 0;

struct fpoint* filelength(f)
int f;
{
  struct fpoint *sz = lseek(f,0,0,SEEK_END);
  seek(f,0,SEEK_SET);	// trick for SolidC :)
  return sz;
}

/* ------- string processing */
#define ENDS(c) (c<=' ' || c==';')
#define CR '\r'

void ini_cright()
{
  int i;
  for(i=0;i<128*16;i++)
  	tr0[i]=0;
}


void sskip() /* Skip space,tab */
{
  while ( (*pt==' ')||(*pt==9) ) pt++;
}

void skip_end() /* Skip text until end */
{
  while (*pt!=CR && *pt!='\n') pt++;
  while (*pt==CR || *pt=='\n') pt++;
}

char skip_comma() /* Skip until comma. (0) - OK, (1) - CR/LF or semicolon */
{
  while (*pt!=',' && *pt!=CR && *pt!='\n' && *pt!=';') pt++;
  if (*pt==',') { pt++; sskip(); return 0;}
  return 1;
}

int cword(s)
char *s;
{
  int i,len=strlen(s);
  for (i=0;i<len;i++) {if(toupper(pt[i])!=s[i]) return -1;}
  pt+=len;
  sskip();
  return 0;
}

void errm(emess) /* error */
char *emess;
{
  printf("ERROR (Line=%03u): ",Line);
  printf("<%s>\n",emess);
}

void errex(emess) /* fatal error */
char *emess;
{
  printf("ERRLINE [");
  while(*pt_line!=CR && *pt_line!='\n' && *pt_line!=0) {printf("%c",*pt_line);pt_line++;}
  printf("]\nERROR (Line=%03u): ",Line);
  printf("<%s>\n",emess);
  exit(-1);
}

int get_string(s, maxL, lens)
char *s;
int maxL;
int *lens;
{
  int i;
  for(i=0;i<maxL;i++) s[i]=' ';
  if(*pt!='\"') {errm("Unknown keyword");return -1;}
  pt++;
  i=0;
LOO1:
  if(*pt=='\"') {pt++;sskip();*lens=i;return 0;}
  i++;
  if (i>maxL) {errm("Too long parameter"); return -1;}
  *s=*pt;
  s++;
  pt++;
  goto LOO1;
}

/* ------- digital enter */

unsigned short dec_n() /* Decimal number */
{
  unsigned short i=0;
  while (isdigit(*pt))
  { i=i*10 + *pt - '0'; pt++;}
  return i;
}

unsigned short hex_n() /* Hexadecimal number (#) */
{
  unsigned short i=0;
  char c;
  while (isxdigit(*pt))
  {
    if (isdigit(*pt)) i= (i<<4) + *pt -'0';
    else {c=toupper(*pt); i = (i<<4) + c -'A'+10;}
    pt++;
  }
  return i;
}

short num(i)  /* Unsigned number (0-ok; -1-bad) */
unsigned int *i;
{
  if (isdigit(*pt)) {*i=dec_n();return 0;}
  if (*pt=='#')
  {
    pt++;
    if(!isxdigit(*pt)) goto ERRNUM;
    *i=hex_n();return 0;
   }
ERRNUM:
  errm("Illegal number");
  return -1;
}


/* ------- auxilary */

int load_file(HB)   /* load next file (0/1 - bin/hobeta) */
int HB;
{
   unsigned int i,j,check,readed,k;
   //char k;
   char hhead[17];
   /* open file */
//   printf("Processing file: \"%s\"...\n",Fname);
   HI=open(Fname,O_RDONLY | O_BINARY);
   if(HI==-1)
    {
      printf("ERROR (Line=%03u, File=\"%s\")\n",Line,Fname);
      perror("FILE ERROR");
      exit(-1);
    }

   if(HB==0)
   /* BIN */
   {
    flenStruct=filelength(HI);
    if(flenStruct->high>0) errex("Binary file longer then 65536 bytes");
    if(flenStruct->high==0 && flenStruct->low==0) errex("Binary file has zero length");
    flen=flenStruct->low;
    blk=(unsigned)(flen/256);
    if(flen%256>0) blk++;
   }
   else
   /* HOBETA */
   {
    read(HI,hhead,17);
    for(i=0;i<8;i++) TRDOSname[i]=hhead[i];
    ftyp=hhead[8];
    fstart=(unsigned)hhead[9]+(unsigned)hhead[10]*256;
    flen=(unsigned)hhead[11]+(unsigned)hhead[12]*256;
    blk=hhead[14];
    check=(unsigned)hhead[15]+(unsigned)hhead[16]*256;
    for(j=i=0; i<0x0F; ++i)
    {
       k = hhead[i];
       j += (k * 0x0101 + i);
    }
    if(j!=check) errex("Illegal checksum in header of hobeta");
   }
   /* write file */
   if (PASS_N)
   { 
     char *mem=(char*)malloc(BUFF_SIZE);
     if(mem==0) errex("Out of memory");
     while((readed=read(HI,mem,BUFF_SIZE))>0) {
     	write(HO,mem,readed);
     }

     free(mem);
   }
   close (HI);
   return 0;
}

void tr_sec(abss) /* get track/sector from absolute sector */
int abss;
{
   _tr=(abss)/16;
   _sec=(abss)%16;
}

void putFAT(cl)
char cl;
{
  /* set FAT parameters */
  char *fd=tr0+Nfile*16;
  tr_sec(asec);
  strcpy(fd,TRDOSname);
  fd[8]=ftyp;
  fd[9]=fstart%256;
  fd[10]=fstart/256;
  fd[11]=flen%256;
  fd[12]=flen/256;
  fd[13]=blk;
  fd[14]=_sec;
  fd[15]=_tr;

  asec+=blk;
  if(asec>=((TRUNC?255:80)*16*2))
  {
    if(TRUNC==0)
      errex("Standart .TRD more than 655360 bytes !");
    else
      errex("Extended .TRD more than 2088960 bytes !");
  }

  Nfile++;

  if(PASS_N)
  {
   printf(
   "[%c%03u] Name=\"%s%c\" Len=%05u Start=%05u Blk=%03u Trk=%03u Sec=%02u\n",
   cl,Nfile,TRDOSname,ftyp,(int)flen,fstart,blk,_tr,_sec);
  }

}


void get_default() /* set default TRDOS file parameters */
{
  int i,j,k,space;
  char *b=Fname;

  for(i=strlen (b);i>0;)
  {
    i--;
    if (b[i]=='\\') break;
  }
  j=strlen(b)-i;
  space=0;
  for(k=0;k<8;k++)
  {
     if(b[k+i]=='.') space=1;
     if(k>=j) space=1;
     if(space==0) TRDOSname[k]=b[k+i];
     else TRDOSname[k]=' ';
  }
  ftyp='C';
  fstart=0;
}

void set_TRD_name()
{
  int i,j,k;
  char *b=LISTname;
  i=strlen(b);
  for(j=0;j<i;j++) b[j]=tolower(b[j]);
  if(b[i-3]!='t' || b[i-2]!='r' || b[i-1]!='l')
      {
       errm("Descriptor must have TRL extention");
       exit(-1);
      }
  strcpy(TRDname,LISTname);
  TRDname[i-1]='d';
}

int get_TYP() /* get file type */
{
  if(skip_comma()) goto ERT;
  if(*pt==',') return 0;
  if(get_string(&ftyp,1,&nnn)==0) return 0;
ERT:
  errex("Illegal type of TR-DOS file");
  return -1;
}

int get_MSDOSname()
{
  if(ENDS(*pt)) errex("Name of file expected");
  if(get_string(Fname,79,&nnn)) errex("Error in name of file");
  Fname[nnn]=0;
  return 0;
}

int get_TRDOSname()
{
  int i;
  if(skip_comma()) goto ERTD;
  if(*pt==',') return 0;
  for(i=0;i<8;i++)TRDOSname[i]=' ';
  if(get_string(TRDOSname,8,&nnn)==0) return 0;
ERTD:
  errex("Error in name of TRDOS file");
  return -1;
}

int get_STRT()
{
  if(skip_comma()) goto ERS;
  if(num(&fstart)==0) return 0;
ERS:
  errex("Error in <start> parameter");
  return -1;
}

/* ------- command translation */

int d_disk(T)
int T;
{
   if(isHEAD)errex("Second header of disk");
   isHEAD++;
   TRUNC=T;
   if(ENDS(*pt)) return 0;
   if(get_string(DNAME,8,&nnn)) errex("Illegal name of TRDOS disk");
   return 0;
}

int d_file(bin_type)
int bin_type;
{
  if (Nfile>=128) errex("More then 128 files");
  get_MSDOSname();
  get_default();
  load_file(bin_type);
  if(!(ENDS(*pt)))get_TRDOSname();
  if(!(ENDS(*pt)))get_TYP();
  if(!(ENDS(*pt)))get_STRT();
  putFAT(bin_type?'H':'B');

  return 0;

}

/* ------- work with TRD */

void ini_pass()
{
 asec=16; /* except t.files */
 Nfile=0;
 Line=1;
 isHEAD=0;
}


char com_type() /* get command number */
{ /* (0-no, 1/2/3/4-normal/extend/bin/hobeta, -1-error) */
  char ct;
  sskip();
  if(ENDS(*pt)) { return 0; }
  ct=-1;
  switch(toupper(*pt))
  {
    case 'N':if(cword("NORMAL")==0)ct=1;break;
    case 'E':if(cword("EXTENDED")==0)ct=2;break;
    case 'B':if(cword("BINARY")==0)ct=3;break;
    case 'H':if(cword("HOBETA")==0)ct=4;break;
    case 'T':if(cword("TRUNCATED")==0)ct=5;break; /* added later */
  }
  if(ct==-1)
      errex("Unknown keyword");
  return ct;
}

int pass(N)
int N;
{
   struct fpoint *len;
   int HI;
   PASS_N=N;
   ini_pass();
   /* load descriptor */
   HI=open(LISTname,O_BINARY | O_RDONLY);
   if (HI==-1){perror("File open ERROR");exit(-1);}
   len=filelength(HI);
   printf("Input file: %s (%u bytes)\n\n",LISTname,len->low);
   ppt=pt=(char *)malloc(len->low+2);
   if(ppt==0) { printf("Out of Memory!\n"); exit(-1); }
   read(HI,ppt,len->low);
   ppt[len->low]='\n'; ppt[len->low+1]=0;
   close(HI);
NEWLINE:
   /* read line */
   if(*pt==0){
   	free(ppt);
   	return 0;
   } /* end of file */
   pt_line=pt;
   switch(com_type())
   {
     case 0:break;
     case 1:if(d_disk(0)!=0)return -1;break;
     case 2:if(d_disk(1)!=0)return -1;break;
     case 3:if(d_file(0)!=0)return -1;break;
     case 4:if(d_file(1)!=0)return -1;break;
     case 5:fTRUNC=1;break;
     default:return -1;
   }
   skip_end();
   Line++;
   goto NEWLINE;

}

int open_trd()
{
  int i;
  HO=open(TRDname,O_BINARY | O_CREAT | O_TRUNC | O_WRONLY);
  if (HO==-1) {perror("Error of disk image making\n"); return -1;}
  /* fill disk header */
  tr_sec(asec);
  freesec=16*(TRUNC?255:80)*2-asec;
  for(i=0;i<9;i++)
     sec9[0xEA+i]=32;
  sec9[0xE1]=_sec;
  sec9[0xE2]=_tr;
  sec9[0xE3]=0x16;
  sec9[0xE4]=Nfile;
  sec9[0xE5]=freesec%256;
  sec9[0xE6]=freesec/256;
  sec9[0xE7]=0x10;
  sec9[0xF4]=00;
  write(HO,tr0,8*256);
  write(HO,sec9,256);
  for (i=0;i<8*256;i++) tr0[i]=0xDD;
  write(HO,tr0,7*256);

  printf("%s TR-DOS Disk (DD80)  Label: \"%8s\"\nFiles: %u  Free sectors: %u\t\n\n",
  (TRUNC?"Extended":"Normal"),DNAME,Nfile,freesec);
  return 0;
}

int close_trd()
{
  if(TRUNC==0)
  {
    unsigned i;
    unsigned int nulldat_sec;
    unsigned int dummy_sec=BUFF_SIZE/256;
    char *pp=(char*)malloc(BUFF_SIZE);
    for (i=0;i<BUFF_SIZE;i++) pp[i]=0xCF;
    if(!fTRUNC && asec<MAXSEC)
    {
      nulldat_sec=MAXSEC-asec;
      while(nulldat_sec>dummy_sec)
      {
        write(HO,pp,BUFF_SIZE);
        nulldat_sec-=dummy_sec;
      }
      if(nulldat_sec>0)
      {
       write(HO,pp,nulldat_sec*256);
      }
    }
    free(pp);
  }
  close(HO);
  return 0;
}

int bin2trd()
{
  if (pass(0)) return -1;
  if (open_trd()) return -1;
  if (pass(1)) return -1;
  if (close_trd()) return -1;
  return 0;
}

int main(n_arg,arg) /****MAIN****/
int n_arg;
char *arg[];
{
  int res;
  printf("\nMaking TRD file from binaries or/and hobeta files (v1.0.2021)");
  printf("\n(c) 1999  Copper Feet (Vyacheslav Mednonogov)");
  printf("\n    2002  Modification by Alexander Shabarshin <me@shaos.net>");
  printf("\n    2021  Sprinter version by Dmitry Mikhaltchenkov <mikhaltchenkov@gmail.com>\n\n");
  if (n_arg==1)
    {
      printf("   Usage:\n\tbin2trd <filename>.trl\n\n");
      return -1;
    }
  strcpy(LISTname,arg[1]);
  strcpy(DNAME,"nonamed ");
  set_TRD_name();
  ini_cright();
  res = bin2trd();
  if(fTRUNC) printf("\nTRD file was truncated\n");
  if(res==0) printf("\nOk!\n\n");
  return res;
}

