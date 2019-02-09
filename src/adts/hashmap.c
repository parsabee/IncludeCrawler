/*
 * Copyright (c) 2017, University of Oregon
 * All rights reserved.

 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:

 * - Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 *
 * - Neither the name of the University of Oregon nor the names of its
 *   contributors may be used to endorse or promote products derived from this
 *   software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include "hashmap.h"
#include <stdlib.h>
#include <string.h>

#define DEFAULT_CAPACITY 16
#define MAX_CAPACITY 134217728L
#define DEFAULT_LOAD_FACTOR 0.75
#define TRIGGER 100	/* number of changes that will trigger a load check */

typedef struct hm_data {
    long size;
    long capacity;
    long changes;
    double load;
    double loadFactor;
    double increment;
    HMEntry **buckets;
} HmData;

struct hmentry {
    struct hmentry *next;
    char *key;
    void *element;
};

/*
 * generate hash value from key; value returned in range of 0..N-1
 */
#define SHIFT 7L			/* should be prime */
static long hash(char *key, long N) {
    long ans = 0L;
    char *sp;

    for (sp = key; *sp != '\0'; sp++)
        ans = ((SHIFT * ans) + *sp) % N;
    return ans;
}

/*
 * traverses the hashmap, calling freeFxn on each element
 * then frees storage associated with the key and the HMEntry structure
 */
static void purge(HmData *hmd, void (*freeFxn)(void *element)) {

    long i;

    for (i = 0L; i < hmd->capacity; i++) {
        HMEntry *p, *q;
        p = hmd->buckets[i];
        while (p != NULL) {
            if (freeFxn != NULL)
                (*freeFxn)(p->element);
            q = p->next;
            free(p->key);
            free(p);
            p = q;
        }
        hmd->buckets[i] = NULL;
    }
}

static void hm_destroy(const HashMap *hm, void (*freeFxn)(void *element)) {
    HmData *hmd = (HmData *)hm->self;
    purge(hmd, freeFxn);
    free(hmd->buckets);
    free(hmd);
    free((void *)hm);
}

static void hm_clear(const HashMap *hm, void (*freeFxn)(void *element)) {
    HmData *hmd = (HmData *)hm->self;
    purge(hmd, freeFxn);
    hmd->size = 0;
    hmd->load = 0.0;
    hmd->changes = 0;
}

/*
 * local function to locate key in a hashmap
 *
 * returns pointer to entry, if found, as function value; NULL if not found
 * returns bucket index in `bucket'
 */
static HMEntry *findKey(HmData *hmd, char *key, long *bucket) {
    long i = hash(key, hmd->capacity);
    HMEntry *p;

    *bucket = i;
    for (p = hmd->buckets[i]; p != NULL; p = p->next) {
        if (strcmp(p->key, key) == 0) {
            break;
        }
    }
    return p;
}

static int hm_containsKey(const HashMap *hm, char *key) {
    HmData *hmd = (HmData *)hm->self;
    long bucket;

    return (findKey(hmd, key, &bucket) != NULL);
}

/*
 * local function for generating an array of HMEntry * from a hashmap
 *
 * returns pointer to the array or NULL if malloc failure
 */
static HMEntry **entries(HmData *hmd) {
    HMEntry **tmp = NULL;
    if (hmd->size > 0L) {
        size_t nbytes = hmd->size * sizeof(HMEntry *);
        tmp = (HMEntry **)malloc(nbytes);
        if (tmp != NULL) {
            long i, n = 0L;
            for (i = 0L; i < hmd->capacity; i++) {
                HMEntry *p;
                p = hmd->buckets[i];
                while (p != NULL) {
                    tmp[n++] = p;
                    p = p->next;
                }
            }
        }
    }
    return tmp;
}

static HMEntry **hm_entryArray(const HashMap *hm, long *len) {
    HmData *hmd = (HmData *)hm->self;
    HMEntry **tmp = entries(hmd);

    if (tmp != NULL)
        *len = hmd->size;
    return tmp;
}

static int hm_get(const HashMap *hm, char *key, void **element) {
    HmData *hmd = (HmData *)hm->self;
    long i;
    HMEntry *p;
    int ans = 0;

    p = findKey(hmd, key, &i);
    if (p != NULL) {
        ans = 1;
        *element = p->element;
    }
    return ans;
}

static int hm_isEmpty(const HashMap *hm) {
    HmData *hmd = (HmData *)hm->self;
    return (hmd->size == 0L);
}

/*
 * local function for generating an array of keys from a hashmap
 *
 * returns pointer to the array or NULL if malloc failure
 */
static char **keys(HmData *hmd) {
    char **tmp = NULL;
    if (hmd->size > 0L) {
        size_t nbytes = hmd->size * sizeof(char *);
        tmp = (char **)malloc(nbytes);
        if (tmp != NULL) {
            long i, n = 0L;
            for (i = 0L; i < hmd->capacity; i++) {
                HMEntry *p;
                p = hmd->buckets[i];
                while (p != NULL) {
                    tmp[n++] = p->key;
                    p = p->next;
                }
            }
        }
    }
    return tmp;
}

static char **hm_keyArray(const HashMap *hm, long *len) {
    HmData *hmd = (HmData *)hm->self;
    char **tmp = keys(hmd);

    if (tmp != NULL)
        *len = hmd->size;
    return tmp;
}

/*
 * routine that resizes the hashmap
 */
static void resize(HmData *hmd) {
    int N;
    HMEntry *p, *q, **array;
    long i, j;

    N = 2 * hmd->capacity;
    if (N > MAX_CAPACITY)
        N = MAX_CAPACITY;
    if (N == hmd->capacity)
        return;
    array = (HMEntry **)malloc(N * sizeof(HMEntry *));
    if (array == NULL)
        return;
    for (j = 0; j < N; j++)
        array[j] = NULL;
    /*
     * now redistribute the entries into the new set of buckets
     */
    for (i = 0; i < hmd->capacity; i++) {
        for (p = hmd->buckets[i]; p != NULL; p = q) {
            q = p->next;
            j = hash(p->key, N);
            p->next = array[j];
            array[j] = p;
        }
    }
    free(hmd->buckets);
    hmd->buckets = array;
    hmd->capacity = N;
    hmd->load /= 2.0;
    hmd->changes = 0;
    hmd->increment = 1.0 / (double)N;
}

/*
 * helper function to insert new (key, element) into table
 */
static int insertEntry(HmData *hmd, char *key, void *element, long i) {
    HMEntry *p = (HMEntry *)malloc(sizeof(HMEntry));
    int ans = 0;

    if (p != NULL) {
        char *q = strdup(key);
        if (q != NULL) {
            p->key = q;
            p->element = element;
            p->next = hmd->buckets[i];
            hmd->buckets[i] = p;
            hmd->size++;
            hmd->load += hmd->increment;
            hmd->changes++;
            ans = 1;
        } else {
            free(p);
        }
    }
    return ans;
}

static int hm_put(const HashMap *hm, char *key, void *element, void **previous) {
    HmData *hmd = (HmData *)hm->self;
    long i;
    HMEntry *p;
    int ans = 0;

    if (hmd->changes > TRIGGER) {
        hmd->changes = 0;
        if (hmd->load > hmd->loadFactor)
            resize(hmd);
    }
    p = findKey(hmd, key, &i);
    if (p != NULL && previous != NULL) {
        *previous = p->element;
        p->element = element;
        ans = 1;
    } else {
        if (previous != NULL)
            *previous = NULL;
        ans = insertEntry(hmd, key, element, i);
    }
    return ans;
}

static int hm_putUnique(const HashMap *hm, char *key, void *element) {
    HmData *hmd = (HmData *)hm->self;
    long i;
    HMEntry *p;
    int ans = 0;

    if (hmd->changes > TRIGGER) {
        hmd->changes = 0;
        if (hmd->load > hmd->loadFactor)
            resize(hmd);
    }
    p = findKey(hmd, key, &i);
    if (p == NULL) {
        ans = insertEntry(hmd, key, element, i);
    }
    return ans;
}

static int hm_remove(const HashMap *hm, char *key, void **element) {
    HmData *hmd = (HmData *)hm->self;
    long i;
    HMEntry *entry;
    int ans = 0;

    entry = findKey(hmd, key, &i);
    if (entry != NULL) {
        HMEntry *p, *c;
        *element = entry->element;
        /* determine where the entry lives in the singly linked list */
        for (p = NULL, c = hmd->buckets[i]; c != entry; p = c, c = c->next)
            ;
        if (p == NULL)
            hmd->buckets[i] = entry->next;
        else
            p->next = entry->next;
        hmd->size--;
        hmd->load -= hmd->increment;
        hmd->changes++;
        free(entry->key);
        free(entry);
        ans = 1;
    }
    return ans;
}

static long hm_size(const HashMap *hm) {
    HmData *hmd = (HmData *)hm->self;
    return hmd->size;
}

static const Iterator *hm_itCreate(const HashMap *hm) {
    HmData *hmd = (HmData *)hm->self;
    const Iterator *it = NULL;
    void **tmp = (void **)entries(hmd);

    if (tmp != NULL) {
        it = Iterator_create(hmd->size, tmp);
        if (it == NULL)
            free(tmp);
    }
    return it;
}

char *hmentry_key(HMEntry *hme) {
    return hme->key;
}

void *hmentry_value(HMEntry *hme) {
    return hme->element;
}

static HashMap template = {
    NULL, hm_destroy, hm_clear, hm_containsKey, hm_entryArray,hm_get,
    hm_isEmpty, hm_keyArray, hm_put, hm_putUnique, hm_remove, hm_size,
    hm_itCreate
}; 

const HashMap *HashMap_create(long capacity, double loadFactor) {
    HashMap *hm = (HashMap *)malloc(sizeof(HashMap));
    long N;
    double lf;
    HMEntry **array;
    long i;

    if (hm != NULL) {
        HmData *hmd = (HmData *)malloc(sizeof(HmData));

        if (hmd != NULL) {
            N = ((capacity > 0) ? capacity : DEFAULT_CAPACITY);
            if (N > MAX_CAPACITY)
                N = MAX_CAPACITY;
            lf = ((loadFactor > 0.000001) ? loadFactor : DEFAULT_LOAD_FACTOR);
            array = (HMEntry **)malloc(N * sizeof(HMEntry *));
            if (array != NULL) {
                hmd->capacity = N;
                hmd->loadFactor = lf;
                hmd->size = 0L;
                hmd->load = 0.0;
                hmd->changes = 0L;
                hmd->increment = 1.0 / (double)N;
                hmd->buckets = array;
                for (i = 0; i < N; i++)
                    array[i] = NULL;
                *hm = template;
                hm->self = hmd;
            } else {
                free(hmd);
                free(hm);
                hm = NULL;
            }
        } else {
            free(hm);
            hm = NULL;
        }
    }
    return hm;
}
