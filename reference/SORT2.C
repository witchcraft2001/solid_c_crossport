/*
MM> Посмотрите, плиз у себя, может у кого-нить есть описание методов
MM> сортировки (quick sort, buble sort, КМП и т.д.). Их там примерно 6
MM> есть. Интересуют иммено алгоритмы с описанием, которые я использую
MM> потом для курсовой работы. Кинте мне, пжалста, или поделитесь urlиком.
MM> Спасибо!

EI> Опишите c пpимеpами на паcкале, пожалуйcта, оcновные методы
EI> cоpтиpовки,
EI> чем больше тем лучше, вcем заpанее огpомное cпаcибол

  Hа. Hо на C (там на сколько я понял главное алгоритмы нужны). Я писал и
компилил под BC3.1. Представляет собой прогу по сбору статистики эффектив-
ности алгоритмов.
Прошу покритиковать :) (хотя опять же сабж был на первом курсе).
----------------
*/

#include<stdio.h>
#include<stdlib.h>
#include<conio.h>

#define SIZE 15

/* Prototypes */
void Binsort();
void Choise();
void Include();
void Bubble();
void Quick();
void Shell();
void Join();
void Prn();
void Test();

unsigned ITERATION,   // Количество пройденых циклов
         EXCHANGES,   //            обменов ячеек
         CONDITIONS;  //            пройденых условий

int Mass[SIZE];

int i, NumElem;
char key;


/* ▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐▐ */
int main()
{

   NumElem = sizeof(Mass) / sizeof(Mass[0]);
   clrscr();

   do {
        for(i=0; i < NumElem; i++) Mass[i] = rand() % 100 - 50;
        clrscr();
        puts("Меню:\n");
        puts("  1. Сортировка обменами (метод пузырька)");
        puts("  2. Сортировка выбором");
        puts("  3. Сортировка простыми вставками");
        puts("  4. Сортировка бинарными вставками (вставка делением пополам)");
        puts("  5. Сортировка методом Шелла");
        puts("  6. Сортировка быстрым методом\n");
        puts("  7. Слияние сортированных массивов");
        puts("  8. Тест на производительность\n");
        puts("  ESC. Выход\n\n->");
        if ((key=getch()) == 27)
            goto done;

        clrscr();
        if (key >= '0' && key <= '6')
           {
             cprintf("\nМассив (оригинал):");
             Prn(Mass, NumElem);
           }

        ITERATION=EXCHANGES=CONDITIONS=0;

        switch(key)
         {
           case '1': Bubble(Mass, NumElem); break;
           case '2': Choise(Mass, NumElem); break;
           case '3': Include(Mass, NumElem); break;
           case '4': Binsort(Mass, NumElem); break;
           case '5': Shell(Mass, NumElem); break;
           case '6': Quick(Mass, 0, NumElem); break;
           case '7': Join(); continue;
           case '8': Test(Mass, NumElem); continue;
           default : continue;
         }
        cprintf("\n(сортированный):");
        Prn(Mass, NumElem);
        cprintf("\n\n\nПри сортировке потребовалось итераций: %d\n",ITERATION);
        cprintf("            произведено обменов ячеек: %d\n",EXCHANGES);
        cprintf("                     пройдено условий: %d\n",CONDITIONS);
        puts("\n\n\nAny key...");
        getch();
   } while(1);

done:
   puts("\n\nSee you...  ;)");
   return 0;
}


/*.......................................................................*/
void Prn(PtrMass, count)
int *PtrMass, count;
{
   int i;
   cprintf("\n[");
   for (i=0; i < count; i++)
         cprintf(" %3d", PtrMass[i]);
   puts("]");
}


/*.......................................................................*/
void Test(PtrMass, count)
int *PtrMass, count;
{

uint ITERATION1, EXCHANGES1, CONDITIONS1, ITERATION2,
     EXCHANGES2, CONDITIONS2, ITERATION3, EXCHANGES3,
     CONDITIONS3, ITERATION4, EXCHANGES4, CONDITIONS4,
     ITERATION5, EXCHANGES5, CONDITIONS5, i, j;

   ITERATION1=EXCHANGES1=CONDITIONS1=ITERATION2=EXCHANGES2=CONDITIONS2=0;
   ITERATION3=EXCHANGES3=CONDITIONS3=ITERATION4=EXCHANGES4=CONDITIONS4=0;
   ITERATION5=EXCHANGES5=CONDITIONS5=0;

   clrscr();
   puts("Сортировка обменами:            пройденых циклов =");
   puts("                                обменов ячейками =");
   puts("                            поставленных условий =\n");
   puts("Сортировка выбором:             пройденых циклов =");
   puts("                                обменов ячейками =");
   puts("                            поставленных условий =\n");
   puts("Сортировка простыми вставками:  пройденых циклов =");
   puts("                                обменов ячейками =");
   puts("                            поставленных условий =\n");
   puts("Сортировка бинарными вставками: пройденых циклов =");
   puts("                                обменов ячейками =");
   puts("                            поставленных условий =\n");
   puts("Сортировка методом Шелла:       пройденых циклов =");
   puts("                                обменов ячейками =");
   puts("                            поставленных условий =\n");
   puts("Сортировка быстрым методом:     пройденых циклов =");
   puts("                                обменов ячейками =");
   puts("                            поставленных условий =");

   for(j=1; j <= 100; j++)
     {
        ITERATION=EXCHANGES=CONDITIONS=0;
        for (i=0; i < count; i++) PtrMass[i] = rand() % 100 - 50;
        Bubble(PtrMass ,count);
        ITERATION1+=ITERATION; EXCHANGES1+=EXCHANGES; CONDITIONS1+=CONDITIONS;
        gotoxy(52,1); cprintf("%d  ",ITERATION1/j);
        gotoxy(52,2); cprintf("%d  ",EXCHANGES1/j);
        gotoxy(52,3); cprintf("%d  ",CONDITIONS1/j);

        ITERATION=EXCHANGES=CONDITIONS=0;
        for (i=0; i < count; i++) PtrMass[i] = rand() % 100 - 50;
        Choise(PtrMass ,count);
        ITERATION2+=ITERATION; EXCHANGES2+=EXCHANGES; CONDITIONS2+=CONDITIONS;
        gotoxy(52,5); cprintf("%d  ",ITERATION2/j);
        gotoxy(52,6); cprintf("%d  ",EXCHANGES2/j);
        gotoxy(52,7); cprintf("%d  ",CONDITIONS2/j);

        ITERATION=EXCHANGES=CONDITIONS=0;
        for (i=0; i < count; i++) PtrMass[i] = rand() % 100 - 50;
        Include(PtrMass ,count);
        ITERATION3+=ITERATION; EXCHANGES3+=EXCHANGES; CONDITIONS3+=CONDITIONS;
        gotoxy(52,9);  cprintf("%d  ",ITERATION3/j);
        gotoxy(52,10); cprintf("%d  ",EXCHANGES3/j);
        gotoxy(52,11); cprintf("%d  ",CONDITIONS3/j);

        ITERATION=EXCHANGES=CONDITIONS=0;
        for (i=0; i < count; i++) PtrMass[i] = rand() % 100 - 50;
        Binsort(PtrMass ,count);
        ITERATION4+=ITERATION; EXCHANGES4+=EXCHANGES; CONDITIONS4+=CONDITIONS;
        gotoxy(52,13); cprintf("%d  ",ITERATION4/j);
        gotoxy(52,14); cprintf("%d  ",EXCHANGES4/j);
        gotoxy(52,15); cprintf("%d  ",CONDITIONS4/j);

        ITERATION=EXCHANGES=CONDITIONS=0;
        for (i=0; i < count; i++) PtrMass[i] = rand() % 100 - 50;
        Shell(PtrMass ,count);
        ITERATION5+=ITERATION; EXCHANGES5+=EXCHANGES; CONDITIONS5+=CONDITIONS;
        gotoxy(52,17); cprintf("%d  ",ITERATION5/j);
        gotoxy(52,18); cprintf("%d  ",EXCHANGES5/j);
        gotoxy(52,19); cprintf("%d  ",CONDITIONS5/j);

        ITERATION=EXCHANGES=CONDITIONS=0;
        for (i=0; i < count; i++) PtrMass[i] = rand() % 100 - 50;
        Quick(PtrMass , 0, count);
        ITERATION5+=ITERATION; EXCHANGES5+=EXCHANGES; CONDITIONS5+=CONDITIONS;
        gotoxy(52,21); cprintf("%d  ",ITERATION5/j);
        gotoxy(52,22); cprintf("%d  ",EXCHANGES5/j);
        gotoxy(52,23); cprintf("%d  ",CONDITIONS5/j);
     }
   puts("\n\n\nOk...");
   getch();
}


/*.......................................................................*/
void Include(PtrMass, count)
int *PtrMass, count;
{
   int i, j, temp;

   for (i=1; i< count; ++i)
     {
      temp=PtrMass[i];
      for (j=i-1; j>=0 && temp<PtrMass[j]; j--)
          {
            ITERATION++;
            EXCHANGES++;
            PtrMass[j+1]=PtrMass[j];
          }
      ITERATION++;
      PtrMass[j+1]=temp;
     }
   ITERATION -= count-1;
}


/*.......................................................................*/
void Binsort(PtrMass, count)
int *PtrMass, count;
{
  int i, j, pos, a, b, middle, num;

  for (i=1; i < count; i++)
      {
        a=0;                     /* Hижняя граница поиска = 1-му эл-ту  */
        b=i;                     /* Верхняя = со 2 по count             */
        EXCHANGES++;
        num=PtrMass[i];          /* Число для кот. нужно найти место    */

        while ( a!=b )           /* ...пока границы не слились...       */
          {
            middle=(a+b)/2;      /* Целая часть ср.арифм. суммы границ  */

            if (num > PtrMass[middle]) /* ..если число >числа стоящ.под */
               {                    /*   номером middle то:             */
                 a=middle+1;        /*   ниж. гран. = центру+1          */
               }                    /*                                  */
             else                   /* или                              */
               {                    /*                                  */
                 b = middle;        /*   верхняя граница = центру...    */
               }
            CONDITIONS++;
            ITERATION++;
          }
        pos=a;                  /* Содержит найденную позицию на кот.   */
                                /* нужно поставить число                */

        for (j=i; j > pos; j--)
          {                         /* Подвигаем (на 1 вправо) эл-ты    */
           PtrMass[j]=PtrMass[j-1]; /* массива лежащие перед элементом, */
           EXCHANGES++;
           ITERATION++;             /* для которого ищется место  осво- */
          }                         /* бождая 1 место                   */

        PtrMass[pos]=num;           /* Устанавливаем элемент на место   */
      }
}


/*.......................................................................*/
void Bubble(PtrMass, count)
int *PtrMass, count;
{
int i,j;
   for (i=0; i<count; i++)
      for (j=i+1; j<count; j++)
          {
            if (PtrMass[i] > PtrMass[j])
               {
                 PtrMass[i]+=PtrMass[j];
                 PtrMass[j]= PtrMass[i] - PtrMass[j];
                 PtrMass[i]-=PtrMass[j];
                 EXCHANGES++;
                 CONDITIONS++;
               }
            ITERATION++;
          }
}


/*.......................................................................*/
void Choise(PtrMass, count)
int *PtrMass, count;
{
int i,j;

   for (i=0; i<count; i++)
      for (j=0; j<count-1; j++)
          {
            if(PtrMass[j]>PtrMass[j+1])
              {
                 PtrMass[j]+=PtrMass[j+1];
                 PtrMass[j+1]=PtrMass[j]-PtrMass[j+1];
                 PtrMass[j]-=PtrMass[j+1];
                 EXCHANGES++;
                 CONDITIONS++;
              }
            ITERATION++;
          }
}


int A[]={-1,1,2,3,3}, B[]={-2,0,2,4,4};

/*.......................................................................*/
/* Слияние двух отсортированных векторов в один */
void Join()
{
   int C[10], i,j,k;

   for (i=j=k=0; k < 10; k++)
     {
       if (A[i] <= B[j])
          { C[k]=A[i]; i++; }
       else
          { C[k]=B[j]; j++; }
     }
    cprintf("\nМассив A[]:");
    Prn(A, sizeof(A) / sizeof(A[0]));
    cprintf("\nМассив B[]:");
    Prn(B, sizeof(B) / sizeof(B[0]));
    cprintf("\nМассив C[]:");
    Prn(C, sizeof(C) / sizeof(C[0]));
    puts("\n\n\nAny key...");
    getch();
}



int aa[]={9,5,3,2,1};

/*.......................................................................*/
void Shell(PtrMass, count)
int *PtrMass, count;
{
  int i, j, gap, k, x;

  for(k=0; k < 5; k++)
    {
      gap = aa[k];
      for(i=gap; i < count; ++i)
        {
         x=PtrMass[i];
         for(j=i-gap; x < PtrMass[j] && j >= 0; j = j-gap)
           {
             PtrMass[j+gap]=PtrMass[j];
             ITERATION++;
             EXCHANGES++;
           }
         PtrMass[j+gap]=x;
        }
    }
}


/*.......................................................................*/
void  Quick(PtrMass, left, right)
int *PtrMass, left, right;
{
   int x, y, i, j;
   i = left;
   j = right;
   x = PtrMass[(left+right) / 2];
   do {
      while(PtrMass[i] < x && i < right) { i++; ITERATION++; }
      while(x < PtrMass[j] && j > left)  { j--; ITERATION++; }

      if(i <= j)
        {
          y=PtrMass[i];
          PtrMass[i]=PtrMass[j];
          PtrMass[j]=y;
          i++;
          j--;
          EXCHANGES++;
          CONDITIONS++;
        }
   } while(i <= j);

   if(left < j) Quick(PtrMass,left,j);
   if(i < right) Quick(PtrMass,i,right);
}
