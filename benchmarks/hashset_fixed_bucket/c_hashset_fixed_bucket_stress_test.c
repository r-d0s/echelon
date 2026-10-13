/*---------------------------------------------------------------------------------
 * c_hashset_fixed_bucket_stress_test.c
 *
 * a FIXED-Bucket Hashset stress test
 * --------------------------------
 *
 * this replicates the echelon file: hashset_fixed_bucket_stress_test.ech
 *
 * unlike the regular version, this hashset NEVER expands, it stays FIXED at 64 buckets
 *
 * why using fixed buckets?
 *
 *  - tests worst-case collision handling with huge chains!
 *  - 1M nodes/64 buckets = 15,625 nodes/bucket (avg!!)
 *  - demos hashset processing & performance under heavy stress.
 *  - a single R/W garbage byte or lost byte will be flagged by Valgrind
 *
 *
 * the -O3 optimisation trap!!
 *
 *   if you compile with -O3, the compiler will probably notice that the look-up loop
 *   doesn't actually do anything with the result.. & it'll probably just ignore the whole loop.
 *   to stop that happening, we increment a volatile counter (found_count) for each look-up.
 *   the final print should forces the loop to actually run.
 *
 * for small tests, change NUM_INSERTS, NUM_LOOKUPS, and NUM_DELETES to smaller values
 * (e.g 20 inserts, 10 lookups & 10 deletes) & un-comment display_all_nodes()
 * to check the hashset.
 *
 * compile: gcc c_hashset_fixed_bucket_stress_test.c -O3 -o c_hashset_fixed_bucket_stress_test
 *
 * run: ./c_hashset_fixed_bucket_stress_test
 *---------------------------------------------------------------------------------
 */

#include <time.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>


#define STR_LEN          40         // length of str Keys
#define BUCKET_SIZE      64         // bucket size (FIXED)
#define MAX_VAL         256         // value range (0->255)

#define NUM_LOOK_UPS     500000     // SEQUENTIAL look-ups
#define NUM_DELETES      500000     // SEQUENTIAL deletes
#define NUM_INSERTS     1000000     // total number nodes

/* NODE CLEAN-UP/FREE FLAG:
 *
 * 0 = Leave KEY, Leave Value
 * 1 = Free Key, Leave Value
 * 2 = Leave Key, Free Value
 * 3 = Free Key, Free Value
 */

#define FREE_FLAG       0

// ---- node data struct ----

typedef struct node {
    char        *key;          // ptr to string
    char        free_flag;
    long int    value;
    struct node *next;
} node;


char * random_string() {                    // random str for Keys

    char *str = malloc(STR_LEN + 1);        // char len

    for (int i = 0; i < STR_LEN; i++) {
        *(str + i) = 97 + (rand() % 26);
    }
    *(str + STR_LEN) = '\0';
    // printf("rand_str: [%s]\n", str);          // debug
    return str;
}

int gen_hash(const char *str) {

    unsigned int total = 0;

    while (*str) {                  // build calc checksum
        total = (total * 31) + *str++;
    }
    return total % BUCKET_SIZE;
}

void display_hash(int pos, node *data) {    // display 1 node

    printf("bucket[%d]\tnode:[%p]\tKEY:[%s]\tVAL:[%ld]\t*next:[%p]\n",
           pos, data, (*data).key, (*data).value, (*data).next);
}

void display_hashset(node **data) {         // display ALL nodes

    for (int i = 0; i < BUCKET_SIZE; i++) {
        node *temp = *(data + i);

        while (temp) {
            display_hash(i, temp);
            temp = (*temp).next;
        }
    }
    printf("-----------------------------\n");
}

int main (int argc, char **args) {

    srand(time(NULL));

    char **keys = malloc(NUM_INSERTS * sizeof(char*));  // ptr array Keys

    node* hashset[BUCKET_SIZE] = { NULL };      // init hashset

    for (int i = 0; i < NUM_INSERTS; i++) {     // build the keys
        *(keys + i) = random_string();
    }

    printf("strings created\n");

    for (int i = 0; i < NUM_INSERTS; i++) {    // insert all nodes..

        int pos = gen_hash(*(keys + i));

        node *curr = *(hashset + pos),
             *prev = NULL;                      // track last node we just looked at

        while (curr) {                          // scan whole chain
            if (!strcmp((*curr).key, *(keys + i))) {
                (*curr).value = rand() % MAX_VAL;
                break;
            }
            prev = curr;                        // keep cpy of last node, before moving on
            curr = (*curr).next;
        }

        if (!curr) {                            // Key not found, so we insert it
            node *new_node        = malloc(sizeof(node));

            (*new_node).free_flag = FREE_FLAG;
            (*new_node).key       = *(keys + i);
            (*new_node).value     = rand() % MAX_VAL;
            (*new_node).next      = NULL;       // by default next is always NULL

            if (prev) {
                (*prev).next = new_node;        // bucket had nodes, prev --> last node, (*prev).next --> NEW node
            } else {
                *(hashset + pos) = new_node;    // empty bucket slot --> push it there
            }
        }
    }

    //display_hashset(hashset);         //  <-- un-commment to see hashset
    printf("add hash done\n");

    volatile int found_count = 0;       // force loop to run..

    for (int j = 0; j < NUM_LOOK_UPS; j++) {    // sequential 1/2 look-ups
        int pos    = gen_hash(*(keys + j));
        node *curr = *(hashset + pos);

        while (curr) {
            if (!strcmp((*curr).key, *(keys + j))) {    // break if matched
                found_count++;
                break;
            }
            curr = (*curr).next;
        }
    }

    printf("total lookups: %d\n", found_count);
    printf("get hash done...\n");

    for (int j = 0; j < NUM_DELETES; j++) {     // sequential 1/2 deletes
        int pos    = gen_hash(*(keys + j));
        node *curr = *(hashset + pos),
             *prev = NULL;                      // track last node just looked at

        while (curr) {
            if (!strcmp((*curr).key, *(keys + j))) {
                if (prev) {
                    (*prev).next = (*curr).next;
                } else {
                    *(hashset + pos) = (*curr).next;
                }

                if ((*curr).free_flag & 1) {        // check flag bit for Key
                    free((*curr).key);
                }

                if ((*curr).free_flag & 2) {        // check flag bit for Value
                    /* IMPORTANT: this is only safe if value is a valid ptr
                     * when FREE_FLAG = 0/1 its never called */
                    free((void *)(*curr).value);    // needs cast else warning
                }
                free(curr);
                break;
            }
            prev = curr;
            curr = (*curr).next;
        }
    }

    printf("del hash done\n");
    //display_hashset(hashset);

    for (int x = 0; x < NUM_INSERTS; x++) {    // free all the strings/keys
        free(*(keys + x));
    }
    free(keys);

    for (int x = 0; x < BUCKET_SIZE; x++) {     // scan all buckets & free remaining nodes
        node *curr = *(hashset + x);

        while (curr) {
            node *temp = curr;
            curr = (*curr).next;

            if ((*temp).free_flag & 1) {    // bitwise Key check
                    free((*temp).key);
            }

            if ((*temp).free_flag & 2) {    // bitwise Value check
                /* IMPORTANT: this is only safe if value is a valid ptr
                 * when FREE_FLAG = 0/1 its never called */
                free((void *)(*temp).value); // cast else warning
            }
            free(temp);
        }
    }

    printf("deleted hashset & strings\n");
    return 0;
}
