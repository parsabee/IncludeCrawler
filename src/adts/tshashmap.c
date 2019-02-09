/*
 * Copyright (c) 2013, Court of the University of Glasgow
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
 * - Neither the name of the University of Glasgow nor the names of its
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

#include "tshashmap.h"
#include "hashmap.h"
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

#define LOCK(hm) &((hm)->lock)

typedef struct tshm_data {
    const HashMap *hm;
    pthread_mutex_t lock;	/* this is a recursive lock */
} TSHmData;

static void tshm_destroy(const TSHashMap *hm, void (*freeFxn)(void *element)) {
    TSHmData *hmd = (TSHmData *)hm->self;

    pthread_mutex_lock(LOCK(hmd));
    hmd->hm->destroy(hmd->hm, freeFxn);
    pthread_mutex_unlock(LOCK(hmd));
    pthread_mutex_destroy(LOCK(hmd));
    free(hmd);
    free((void *)hm);
}

static void tshm_clear(const TSHashMap *hm, void (*freeFxn)(void *element)) {
    TSHmData *hmd = (TSHmData *)hm->self;

    pthread_mutex_lock(LOCK(hmd));
    hmd->hm->clear(hmd->hm, freeFxn);
    pthread_mutex_unlock(LOCK(hmd));
}

static void tshm_lock(const TSHashMap *hm) {
    TSHmData *hmd = (TSHmData *)hm->self;

    pthread_mutex_lock(LOCK(hmd));
}

static void tshm_unlock(const TSHashMap *hm) {
    TSHmData *hmd = (TSHmData *)hm->self;

    pthread_mutex_unlock(LOCK(hmd));
}

static int tshm_containsKey(const TSHashMap *hm, char *key) {
    TSHmData *hmd = (TSHmData *)hm->self;
    int result;

    pthread_mutex_lock(LOCK(hmd));
    result = hmd->hm->containsKey(hmd->hm, key);
    pthread_mutex_unlock(LOCK(hmd));
    return  result;
}

static HMEntry **tshm_entryArray(const TSHashMap *hm, long *len) {
    TSHmData *hmd = (TSHmData *)hm->self;
    HMEntry **result;

    pthread_mutex_lock(LOCK(hmd));
    result = hmd->hm->entryArray(hmd->hm, len);
    pthread_mutex_unlock(LOCK(hmd));
    return  result;
}

static int tshm_get(const TSHashMap *hm, char *key, void **element) {
    TSHmData *hmd = (TSHmData *)hm->self;
    int result;

    pthread_mutex_lock(LOCK(hmd));
    result = hmd->hm->get(hmd->hm, key, element);
    pthread_mutex_unlock(LOCK(hmd));
    return  result;
}

static int tshm_isEmpty(const TSHashMap *hm) {
    TSHmData *hmd = (TSHmData *)hm->self;
    int result;

    pthread_mutex_lock(LOCK(hmd));
    result = hmd->hm->isEmpty(hmd->hm);
    pthread_mutex_unlock(LOCK(hmd));
    return  result;
}

static char **tshm_keyArray(const TSHashMap *hm, long *len) {
    TSHmData *hmd = (TSHmData *)hm->self;
    char **result;

    pthread_mutex_lock(LOCK(hmd));
    result = hmd->hm->keyArray(hmd->hm, len);
    pthread_mutex_unlock(LOCK(hmd));
    return  result;
}

static int tshm_put(const TSHashMap *hm, char *key, void *element, void **previous) {
    TSHmData *hmd = (TSHmData *)hm->self;
    int result;

    pthread_mutex_lock(LOCK(hmd));
    result = hmd->hm->put(hmd->hm, key, element, previous);
    pthread_mutex_unlock(LOCK(hmd));
    return  result;
}

static int tshm_putUnique(const TSHashMap *hm, char *key, void *element) {
    TSHmData *hmd = (TSHmData *)hm->self;
    int result;

    pthread_mutex_lock(LOCK(hmd));
    result = hmd->hm->putUnique(hmd->hm, key, element);
    pthread_mutex_unlock(LOCK(hmd));
    return  result;
}

static int tshm_remove(const TSHashMap *hm, char *key, void **element) {
    TSHmData *hmd = (TSHmData *)hm->self;
    int result;

    pthread_mutex_lock(LOCK(hmd));
    result = hmd->hm->remove(hmd->hm, key, element);
    pthread_mutex_unlock(LOCK(hmd));
    return  result;
}

static long tshm_size(const TSHashMap *hm) {
    TSHmData *hmd = (TSHmData *)hm->self;
    long result;

    pthread_mutex_lock(LOCK(hmd));
    result = hmd->hm->size(hmd->hm);
    pthread_mutex_unlock(LOCK(hmd));
    return  result;
}

static const TSIterator *tshm_itCreate(const TSHashMap *hm) {
    TSHmData *hmd = (TSHmData *)hm->self;
    const TSIterator *it = NULL;
    void **tmp;
    long len;

    pthread_mutex_lock(LOCK(hmd));
    tmp = (void **)hmd->hm->entryArray(hmd->hm, &len);
    if (tmp != NULL) {
        it = TSIterator_create(LOCK(hmd), len, tmp);
        if (it == NULL)
            free(tmp);
    }
    if (it == NULL)
        pthread_mutex_unlock(LOCK(hmd));
    return it;
}

static TSHashMap template = {
    NULL, tshm_destroy, tshm_clear, tshm_lock, tshm_unlock, tshm_containsKey,
    tshm_entryArray, tshm_get, tshm_isEmpty, tshm_keyArray, tshm_put,
    tshm_putUnique, tshm_remove, tshm_size, tshm_itCreate
};

const TSHashMap *TSHashMap_create(long capacity, double loadFactor) {
    TSHashMap *tshm = (TSHashMap *)malloc(sizeof(TSHashMap));

    if (tshm != NULL) {
        TSHmData *hmd = (TSHmData *)malloc(sizeof(TSHmData));

        if (hmd != NULL) {
            hmd->hm = HashMap_create(capacity, loadFactor);

            if (hmd->hm != NULL) {
                pthread_mutexattr_t ma;
                pthread_mutexattr_init(&ma);
                pthread_mutexattr_settype(&ma, PTHREAD_MUTEX_RECURSIVE);
                pthread_mutex_init(LOCK(hmd), &ma);
                pthread_mutexattr_destroy(&ma);
                *tshm = template;
                tshm->self = hmd;
            } else {
                free(hmd);
                free(tshm);
                tshm = NULL;
            }
        } else {
            free(tshm);
            tshm = NULL;
        }
    }
    return tshm;
}
