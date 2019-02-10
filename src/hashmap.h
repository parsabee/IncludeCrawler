#ifndef _HASHMAP_H_
#define _HASHMAP_H_

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

#include "iterator.h"			/* needed for factory method */

/*
 * interface definition for generic hashmap implementation
 *
 * patterned roughly after Java 6 HashMap generic class with String keys
 */

typedef struct hashmap HashMap;		/* forward reference */
typedef struct hmentry HMEntry;		/* opaque type definition */

/*
 * create a hashmap with the specified capacity and load factor;
 * if capacity == 0, a default initial capacity (16 elements) is used
 * if loadFactor == 0.0, a default load factor (0.75) is used
 * if number of elements/number of buckets exceeds the load factor, the
 * table is resized, doubling the number of buckets, up to a max number
 * of buckets (134,217,728)
 *
 * returns a pointer to the hashmap, or NULL if there are malloc() errors
 */
const HashMap *HashMap_create(long capacity, double loadFactor);

/*
 * now define struct hashmap
 */
struct hashmap {
/*
 * the private data of the hashmap
 */
    void *self;

/*
 * destroys the hashmap; for each HMEntry, if freeFxn != NULL,
 * it is invoked on the element in that entry ; the storage associated with
 * the hashmap is then returned to the heap
 */
    void (*destroy)(const HashMap *hm, void (*freeFxn)(void *element));

/*
 * clears all elements from the hashmap; for each HMEntry,
 * if freeFxn != NULL, it is invoked on the element in that entry;
 * any storage associated with the entry in the hashmap is then
 * returned to the heap
 *
 * upon return, the hashmap will be empty
 */
    void (*clear)(const HashMap *hm, void (*freeFxn)(void *element));

/*
 * returns 1 if hashmap has an entry for `key', 0 otherwise
 */
    int (*containsKey)(const HashMap *hm, char *key);

/*
 * returns an array containing all of the entries of the hashmap in
 * an arbitrary order; returns the length of the list in `*len'
 *
 * returns pointer to HMEntry * array of elements, or NULL if malloc failure
 *
 * NB - the caller is responsible for freeing the HMEntry * array when finished
 */
    HMEntry **(*entryArray)(const HashMap *hm, long *len);

/*
 * returns the element to which the specified key is mapped in `*element'
 *
 * returns 1 if successful, 0 if no mapping for `key'
 */
    int (*get)(const HashMap *hm, char *key, void **element);

/*
 * returns 1 if hashmap is empty, 0 if it is not
 */
    int (*isEmpty)(const HashMap *hm);

/*
 * returns an array containing all of the keys in the hashmap in
 * an arbitrary order; returns the length of the list in `*len'
 *
 * returns pointer to char * array of keys, or NULL if malloc failure
 *
 * NB - the caller is responsible for freeing the char * array when finished
 */
    char **(*keyArray)(const HashMap *hm, long *len);

/*
 * associates `element' with key'; if this replaces an existing mapping, the
 * old value is returned in `*previous'; othersize *previous == NULL
 *
 *
 * returns 1 if successful, 0 if not (malloc failure)
 */
    int (*put)(const HashMap *hm, char *key, void *element, void **previous);

/*iw
 * associates `element' with `key'; fails if `key' is already present
 *
 * returns 1 if successful, 0 if not (malloc failure or already present)
 */
    int (*putUnique)(const HashMap *hm, char *key, void *element);

/*
 * removes the entry associated with `key' if one exists; returns element
 * associated with key in `*element'
 *
 * returns 1 if successful, 0 if no element associated with `key'
 */
    int (*remove)(const HashMap *hm, char *key, void **element);

/*
 * returns the number of mappings in the hashmap
 */
    long (*size)(const HashMap *hm);

/*
 * create generic iterator to this hashmap
 * note that iterator will return pointers to HMEntry's
 *
 * returns pointer to the Iterator or NULL if failure
 */
    const Iterator *(*itCreate)(const HashMap *hm);
};

/*
 * accessor methods for obtaining key and value from an HMEntry
 * used with return from it_next() on iterator and with elements of HMEntry *
 * array returned by entryArray()
 */
char *hmentry_key(HMEntry *hme);
void *hmentry_value(HMEntry *hme);

#endif /* _HASHMAP_H_ */
