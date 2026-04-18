#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>

unsigned char rotor[] = "EKMFLGDQVZNTOWYHXUSPAIBRCJAJDKSIRUXBLHWTMCQGZNPYFVOEBDFHJLCPRTXVZNYEIWGAKMUSQOESOVPZJAYQUIRHXLNFTGKDCMWBVZBRGITYUPSDNHLXAWMJQOFECK";
unsigned char ref[] = "YRUHQSLDPXNGOKMIEBFZCWVJAT";
unsigned char notch[] = "QEVJZ";

unsigned char order[3] = { 3, 1, 2 };
unsigned char rings[3] = { 'W', 'X', 'T' };
unsigned char pos[3] = { 'A', 'W', 'E' };
unsigned char plug[] = "AMTE";

void step_rotors(flag)
int *flag;
{
    pos[0]++;
    if (pos[0] > 'Z') pos[0] -= 26;

    if (*flag) {
        pos[1]++;
        if (pos[1] > 'Z') pos[1] -= 26;
        pos[2]++;
        if (pos[2] > 'Z') pos[2] -= 26;
        *flag = 0;
    }

    if (pos[0] == notch[order[0] - 1]) {
        pos[1]++;
        if (pos[1] > 'Z') pos[1] -= 26;
        if (pos[1] == notch[order[1] - 1]) *flag = 1;
    }
}

int plug_swap(ch)
int ch;
{
    int i;
    for (i = 0; plug[i]; i += 2) {
        if (ch == plug[i]) return plug[i + 1];
        if (ch == plug[i + 1]) return plug[i];
    }
    return ch;
}

int main()
{
    int ch;
    int i, j;
    int flag;
    unsigned int n;

    flag = 0;
    n = 0;

    puts("ENIGMA (K&R port). Input ends with dot '.'");

    while (1) {
        ch = getchar();
        if (ch == EOF || ch == '.') break;

        ch = toupper(ch);
        if (!isalpha(ch)) continue;

        step_rotors(&flag);
        ch = plug_swap(ch);

        for (i = 0; i < 3; ++i) {
            ch += pos[i] - 'A';
            if (ch > 'Z') ch -= 26;

            ch -= rings[i] - 'A';
            if (ch < 'A') ch += 26;

            ch = rotor[(order[i] - 1) * 26 + ch - 'A'];

            ch += rings[i] - 'A';
            if (ch > 'Z') ch -= 26;

            ch -= pos[i] - 'A';
            if (ch < 'A') ch += 26;
        }

        ch = ref[ch - 'A'];

        for (i = 2; i >= 0; --i) {
            ch += pos[i] - 'A';
            if (ch > 'Z') ch -= 26;

            ch -= rings[i] - 'A';
            if (ch < 'A') ch += 26;

            for (j = 0; j < 26; ++j) {
                if (rotor[(order[i] - 1) * 26 + j] == ch) break;
            }
            ch = j + 'A';

            ch += rings[i] - 'A';
            if (ch > 'Z') ch -= 26;

            ch -= pos[i] - 'A';
            if (ch < 'A') ch += 26;
        }

        ch = plug_swap(ch);

        putchar(ch);
        ++n;
        if ((n % 5) == 0) {
            if ((n % 55) == 0) putchar('\n');
            else putchar(' ');
        }
    }

    putchar('\n');
    return 0;
}
