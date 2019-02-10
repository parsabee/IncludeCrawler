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

/*
 * implementation for thread-safe generic unbounded queue
 */

#include "tsuqueue.h"
#include "uqueue.h"
#include <stdlib.h>
#include <pthread.h>

#define LOCK(uq) &((uq)->lock)
#define COND(uq) &((uq)->cond)

typedef struct tsuq_data {
    const UQueue *uq;
    pthread_mutex_t lock;	/* this is a recursive lock */
    pthread_cond_t cond;        /* needed for take */
} TSUqData;

static void tsuq_destroy(const TSUQueue *tsuq, void (*freeFxn)(void *element)) {
    TSUqData *uqd = (TSUqData *)tsuq->self;

    pthread_mutex_lock(LOCK(uqd));
    uqd->uq->destroy(uqd->uq, freeFxn);
    pthread_mutex_unlock(LOCK(uqd));
    pthread_mutex_destroy(LOCK(uqd));
    pthread_cond_destroy(COND(uqd));
    free(uqd);
    free((void *)tsuq);
}

static void tsuq_clear(const TSUQueue *tsuq, void (*freeFxn)(void *element)) {
    TSUqData *uqd = (TSUqData *)tsuq->self;

    pthread_mutex_lock(LOCK(uqd));
    uqd->uq->clear(uqd->uq, freeFxn);
    pthread_mutex_unlock(LOCK(uqd));
}

static void tsuq_lock(const TSUQueue *tsuq) {
    TSUqData *uqd = (TSUqData *)tsuq->self;

    pthread_mutex_lock(LOCK(uqd));
}

static void tsuq_unlock(const TSUQueue *tsuq) {
    TSUqData *uqd = (TSUqData *)tsuq->self;

    pthread_mutex_unlock(LOCK(uqd));
}

static int tsuq_add(const TSUQueue *tsuq, void *element) {
    TSUqData *uqd = (TSUqData *)tsuq->self;
    int result;

    pthread_mutex_lock(LOCK(uqd));
    result = uqd->uq->add(uqd->uq, element);
    pthread_cond_signal(COND(uqd));
    pthread_mutex_unlock(LOCK(uqd));
    return result;
}

static int tsuq_peek(const TSUQueue *tsuq, void **element) {
    TSUqData *uqd = (TSUqData *)tsuq->self;
    int result;

    pthread_mutex_lock(LOCK(uqd));
    result = uqd->uq->peek(uqd->uq, element);
    pthread_mutex_unlock(LOCK(uqd));
    return result;
}

static int tsuq_remove(const TSUQueue *tsuq, void **element) {
    TSUqData *uqd = (TSUqData *)tsuq->self;
    int result;

    pthread_mutex_lock(LOCK(uqd));
    result = uqd->uq->remove(uqd->uq, element);
    pthread_mutex_unlock(LOCK(uqd));
    return result;
}

static void tsuq_take(const TSUQueue *tsuq, void **element) {
    TSUqData *uqd = (TSUqData *)tsuq->self;

    pthread_mutex_lock(LOCK(uqd));
    while (uqd->uq->size(uqd->uq) == 0L)
        pthread_cond_wait(COND(uqd), LOCK(uqd));
    (void)uqd->uq->remove(uqd->uq, element);
    pthread_mutex_unlock(LOCK(uqd));
}

static long tsuq_size(const TSUQueue *tsuq) {
    TSUqData *uqd = (TSUqData *)tsuq->self;
    long result;

    pthread_mutex_lock(LOCK(uqd));
    result = uqd->uq->size(uqd->uq);
    pthread_mutex_unlock(LOCK(uqd));
    return result;
}

static int tsuq_isEmpty(const TSUQueue *tsuq) {
    TSUqData *uqd = (TSUqData *)tsuq->self;
    int result;

    pthread_mutex_lock(LOCK(uqd));
    result = uqd->uq->isEmpty(uqd->uq);
    pthread_mutex_unlock(LOCK(uqd));
    return result;
}

static void **tsuq_toArray(const TSUQueue *tsuq, long *len) {
    TSUqData *uqd = (TSUqData *)tsuq->self;
    void **result;

    pthread_mutex_lock(LOCK(uqd));
    result = uqd->uq->toArray(uqd->uq, len);
    pthread_mutex_unlock(LOCK(uqd));
    return result;
}

static const TSIterator *tsuq_itCreate(const TSUQueue *tsuq) {
    TSUqData *uqd = (TSUqData *)tsuq->self;
    const TSIterator *it = NULL;
    void **tmp;
    long len;

    pthread_mutex_lock(LOCK(uqd));
    tmp = uqd->uq->toArray(uqd->uq, &len);
    if (tmp != NULL) {
        it = TSIterator_create(LOCK(uqd), len, tmp);
        if (it == NULL)
            free(tmp);
    }
    if (it == NULL)
        pthread_mutex_unlock(LOCK(uqd));
    return it;
}

static TSUQueue template = {
    NULL, tsuq_destroy, tsuq_clear, tsuq_lock, tsuq_unlock,
    tsuq_add, tsuq_peek, tsuq_remove, tsuq_take,
    tsuq_size, tsuq_isEmpty, tsuq_toArray, tsuq_itCreate
};

const TSUQueue *TSUQueue_create(void) {
    TSUQueue *tsuq = (TSUQueue *)malloc(sizeof(TSUQueue));

    if (tsuq != NULL) {
        TSUqData *uqd = (TSUqData *)malloc(sizeof(TSUqData));

        if (uqd != NULL) {
            uqd->uq = UQueue_create();

            if (uqd->uq != NULL) {
                pthread_mutexattr_t ma;
                pthread_mutexattr_init(&ma);
                pthread_mutexattr_settype(&ma, PTHREAD_MUTEX_RECURSIVE);
                pthread_mutex_init(LOCK(uqd), &ma);
                pthread_mutexattr_destroy(&ma);
                pthread_cond_init(COND(uqd), NULL);
                *tsuq = template;
                tsuq->self = uqd;
            } else {
                free(uqd);
                free(tsuq);
                tsuq = NULL;
            }
        } else {
            free(tsuq);
            tsuq = NULL;
        }
    }
    return tsuq;
}
