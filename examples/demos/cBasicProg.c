#include <stdio.h>

int main(int argc, char **args, char **envp){
    printf("\nhELL0! tHiS pR0G wAS fiRED 0FF fR0M: [%s]!\n", *args);

    for(char c = 0; c < 2; c++){
        char **tmpArgs = args;
        int  index = 0;
        while(*tmpArgs){
            printf("args[%d] --> [%s]\n", index++, *tmpArgs++);     // dump all args..
        }

        char **tmpEnv = envp;
        while(*tmpEnv){
            printf("\teXAMiNE tHESE eNV vARS: [%s]\n", *tmpEnv++);  // and dump envp...
        }
        printf("----------------------------\n");
    }
    return 0;
}
