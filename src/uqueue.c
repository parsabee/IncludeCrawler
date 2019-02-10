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
 * implementation for generic unbounded FIFO queue
 */

#include "uqueue.h"
#include "linkedlist.h"
#include <stdlib.h>

typedef struct uq_data {
    const LinkedList *ll;
} UqData;

static void uq_destroy(const UQueue *uq, void (*freeFxn)(void *element)) {
    UqData *uqd = (UqData *)uq->self;
    (uqd->ll)->destroy(uqd->ll, freeFxn);
    free(uqd);
    free((void *)uq);
}

static void uq_clear(const UQueue *uq, void (*freeFxn)(void *element)) {
    UqData *uqd = (UqData *)uq->self;
    (uqd->ll)->clear(uqd->ll, freeFxn);
}

static int uq_add(const UQueue *uq, void *element) {
    UqData *uqd = (UqData *)uq->self;
    int result;
    result = (uqd->ll)->add(uqd->ll, element);
    return result;
}

static int uq_peek(const UQueue *uq, void **element) {
    UqData *uqd = (UqData *)uq->self;
    int result;
    result = (uqd->ll)->getFirst(uqd->ll, element);
    return result;
}

static int uq_remove(const UQueue *uq, void **element) {
    UqData *uqd = (UqData *)uq->self;
    int result;
    result = (uqd->ll)->removeFirst(uqd->ll, element);
    return result;
}

static long uq_size(const UQueue *uq) {
    UqData *uqd = (UqData *)uq->self;
    long result;
    result = (uqd->ll)->size(uqd->ll);
    return result;
}

static int uq_isEmpty(const UQueue *uq) {
    UqData *uqd = (UqData *)uq->self;
    return ((uqd->ll)->size(uqd->ll) == 0L);
}

static void **uq_toArray(const UQueue *uq, long *len) {
    UqData *uqd = (UqData *)uq->self;
    void **result;
    result = (uqd->ll)->toArray(uqd->ll, len);
    return result;
}

static const Iterator *uq_itCreate(const UQueue *uq) {
    UqData *uqd = (UqData *)uq->self;
    const Iterator *it = NULL;
    void **tmp;
    long len;

    tmp = (uqd->ll)->toArray(uqd->ll, &len);
    if (tmp != NULL) {
        it = Iterator_create(len, tmp);
        if (it == NULL)
            free(tmp);
    }
    return it;
}

static UQueue template = {
    NULL, uq_destroy, uq_clear, uq_add, uq_peek, uq_remove, uq_size,
    uq_isEmpty, uq_toArray, uq_itCreate
};

const UQueue *UQueue_create(void) {
    UQueue *uq = (UQueue *)malloc(sizeof(UQueue));

    if (uq != NULL) {
        UqData *uqd = (UqData *)malloc(sizeof(UqData));

        if (uqd != NULL) {
            uqd->ll = LinkedList_create();

            if (uqd->ll != NULL) {
                *uq = template;
                uq->self = uqd;
            } else {
                free(uqd);
                free(uq);
                uq = NULL;
            }
        } else {
            free(uq);
            uq = NULL;
        }
    }
    return uq;
}
