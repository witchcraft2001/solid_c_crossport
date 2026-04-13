/* This is HOBCRC utility to check hobeta checksum */
/* Written for SOLiD C by Hard (D.Mikhaltchenkov) in June 2021 */
/* mikhaltchenkov@gmail.com */
/* This software is PUBLIC DOMAIN */
/* Use it one your own RISK ! */

#include <stdio.h>
#include <io.h>
#include <ctype.h>
#include <dos.h>

char check_hobeta(filename)
char *filename;
{
        unsigned int i,j,check,readed,k;
        /* parameters of current file */
        char TRDOSname[9]; /* name of tr-dos file */
        char ftyp; /* type */
        unsigned fstart; /* start address */
        unsigned blk; /* file length in 256 blocks */
        struct fpoint *flenStruct; /* real file length - structure */
        unsigned int flen; /* real file length */

        char hhead[17];
        /* open file */
        int HI=open(filename,O_RDONLY);
        if(HI==-1)
        {
                printf("ERROR (File=\"%s\")\n",filename);
                perror("FILE ERROR");
                exit(-1);
        }
        read(HI,hhead,17);
        close(HI);

        for(i=0;i<8;i++)
                TRDOSname[i]=hhead[i];
        TRDOSname[8]=0;

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

        printf("  Name=\"%s%c\" Len=%05u Start=%05u Blk=%03u Crc=%05u\n", TRDOSname,ftyp,flen,fstart,blk,check);

        if(j!=check) {
        	printf("\nIllegal checksum in header of hobeta!\nWas:  %05u\nReal: %05u\n\n",check,j);
        	return -1;
        }
        printf("\nOk!\n\n");

        return 0;
}

int main(n_arg,arg) /****MAIN****/
int n_arg;
char *arg[];
{
        int res;
        printf("\nHobetaCrc v.0.1");
        printf("\nChecking checksum in Hobeta files");
        printf("\nby Dmitry Mikhaltchenkov <mikhaltchenkov@gmail.com>\n\n");
        if (n_arg==1)
        {
        printf("   Usage:\n\thobcrc <filename>\n\n");
        return -1;
        }
        return check_hobeta(arg[1]);
}
