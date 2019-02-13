/*
 * created by Parsa Bagheri
 * this software uses Open Source material,
 * I am grateful to the developers of noted material for their contirbutions to Open Source
 * 
 * The LICENSE and Copyright information can be found in ./IncludeCrawler/src/LICENSE
 * The link to the GitHub repository: https://github.com/jsventek/ADTsv2
 */

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <pthread.h>
#include "tslinkedlist.h"
#include "tshashmap.h"
#include "tsiterator.h"
#include "tsorderedset.h"
#include "tsuqueue.h"

#define USAGE "Usage: include_crawler [-Idir] ... file.ext ..."
#define LINE_SIZE 4096


pthread_cond_t cond; /*condition variable for threads to knwo when to terminate*/
pthread_mutex_t lock; /*mutex lock to be used with condition variable when waiting*/

char **directories; /*array of directory paths*/
int dir_count; /*holds the count of directories to be searched*/
int file_count; /*holds the count of files to be searched*/
const TSUQueue *work_q = NULL; /*use a queue structure for work queue*/
const TSHashMap *the_table = NULL;
int fstart = 1; /*index in the arguments where the files start*/
int active_threads = 0;

static void freeLL(void *a){
	/*
	 * Function to clear the enteries of the table
	 */
	if(a != NULL){
		TSLinkedList *ll = (TSLinkedList *) a;
		ll->destroy(ll, free);
	}
}

static void freeArg(char **L){
	/*
	 * static function to free the strdup'ed command line argument
	 */
	if(L != NULL){
		free(L[0]);
		free(L[1]);
		free(L);
	}
}

void cleanUp(){
	/*
	 * Clean-Up routine
	 */
	if(directories != NULL){
		int i;
		for(i=0; i<dir_count; i++){
			free(directories[i]);
		}
		free(directories);
	}
	if(work_q != NULL){
		work_q->destroy(work_q, NULL);
	}
	if(the_table != NULL){
		the_table->destroy(the_table, freeLL);
	}

	pthread_mutex_destroy(&lock);
	pthread_cond_destroy(&cond);
}

static int scmp(void *a, void *b) {
	/*
	 * static funciton used for comparison function in hashmap
	 */
	return strcmp((char *)a, (char *)b);
}

static void RemoveSpaces(char* source)
{
	/*
	 * Helper function to remove all the white spaces
	 */
	  char* i = source;
	  char* j = source;
	  while(*j != 0)
	  {
	    *i = *j++;
	    if(*i != ' ')
	      i++;
	  }
	  *i = 0;
}

static FILE *openFile(char *afile){
	/*
	 * Helper function that takes a path and opens a file in that path
	 * and returns a file pointer
	 */
	char buf[512];
	int i;
	FILE *fp = NULL;
	for(i=0; i<dir_count; i++){
		strcpy(buf, directories[i]);
		strcat(buf, afile);
		fp = fopen(buf, "r");
		if(fp != NULL){
			return fp;
		}
	}
	return NULL;
}
void printDependencies(FILE *fp, const TSHashMap *the_table, const TSOrderedSet *printed, const TSLinkedList *to_be_printed){
	/*
	 * Helper function to print out the dependencies in the table
	 * and update the printed set and to_be_printed linked list
	 */
	char *fn;
	TSLinkedList *ll;
	long i;
	long len;
	while(to_be_printed->removeFirst(to_be_printed, (void **)&fn)){
		if(the_table->get(the_table, fn, (void **)&ll)){
			len = ll->size(ll);
			for(i=0; i<len; i++){
				char *name;
				if(ll->get(ll, i, (void **)&name)){
					if(!printed->contains(printed, (void *)name)){
						fprintf(fp, " %s", name);
						printed->add(printed, (void *)name);
						to_be_printed->addLast(to_be_printed, (void *)name);
					}
				}
			}
		}
	}
}

int process(char *afile, const TSLinkedList *ll, const TSHashMap *hm, const TSUQueue *wq){
	char buf[LINE_SIZE];
	FILE *fp;

	fp = openFile(afile);
	if(fp == NULL){
		fprintf(stderr, "Unable to open %s\n", afile);
		return 0;
	}
	char *include = "#include";
	while(fgets(buf, LINE_SIZE, fp)){
		RemoveSpaces(buf);
		int i;
		int isInclude = 1;
		for(i=0; i<8; i++){
			if(buf[i] != include[i]){
				isInclude = 0;
				break;
			}
		}
		/*if the line starts with #include*/
		if(isInclude){
			int len = strlen(buf);
			if(len > 10){
				if(buf[8] == '\"'){
					int len_count = 0;
					i=9;
					while(buf[i] != '\"'){
						len_count++;
						i++;
					}
					char *dependecy = strndup(buf+9, len_count);					
					ll->addLast(ll, (void *)dependecy);
					if(!hm->containsKey(hm, dependecy)){
						const TSLinkedList *deps = TSLinkedList_create();
						if(deps == NULL){
							fprintf(stderr, "In function `process' failed to create linked list deps\n");
							return 0;
						}
						if(!hm->put(hm, dependecy, (void *)deps, NULL)){
							fprintf(stderr, "In function `process' failed to add to the table\n");
							return 0;
						}
						if(!wq->add(wq, (void *)dependecy)){
							fprintf(stderr, "In function `process' failed to add to work queue\n");
							return 0;
						}

						pthread_mutex_lock(&lock);
						active_threads++; /* more work added */
						pthread_mutex_unlock(&lock);
					}
				}
			}
		}
	}
	fclose(fp);
	return 1;
}

int getDirNum(const char *path){
	/*
	 * helper function to get the number of directories sepereated by ":" in a string
	 * takes a char string containing directories seperated by ":"
	 * returns the number of directories
	 */

	int count = 0;
	int counter = 0;
	while(path[counter] != '\0'){
		if(path[counter] == ':')
			count++;
		counter++;
	}
	if(counter>0)
		count++;
	return count;
}

char *addSlash(char *argv, int arg_len){
	/*
	 * Helper funciton to add a slash to the end of the path
	 * if it doesn't already have a slash at the end
	 */
	if(arg_len >= 3){
		if(argv[0] == '-' && argv[1] == 'I'){
			if(argv[arg_len-1] != '/'){
				char *dir = (char *)malloc(arg_len);/*size len because we need to get rid of the '-' 'I' and add '/' and '\0'*/
				int j, z;
				for(j=2, z=0; j<arg_len; j++, z++){
					dir[z] = argv[j];
				}
				dir[z] = '/';
				dir[z+1] = '\0';
				return dir;
			}else{
				char *dir = (char *)malloc(arg_len-1);/* arg_len - 1 because we're getting rid of '-''I' and add '\0'*/
				int j, z;
				for(j=2, z=0; j<arg_len; j++, z++){
					dir[z] = argv[j];
				}
				return dir;
			}
		}else{
			if(argv[arg_len-1] != '/'){
				char *dir = (char *)malloc(arg_len + 2);/*size len + 2 because we need to add '/' and '\0'*/
				int j;
				for(j=0; j<arg_len; j++){
					dir[j] = argv[j];
				}
				dir[j] = '/';
				dir[j+1] = '\0';
				return dir;
			}else{
				char *dir = (char *)malloc(arg_len+1);/* arg_len - 1 because we're adding '\0'*/
				int j, z;
				for(j=0; j<arg_len; j++){
					dir[j] = argv[j];
				}
				return dir;
			}
		}
	}else{
		if(argv[arg_len-1] != '/'){
			char *dir = (char *)malloc(arg_len + 2);/*size len + 2 because we need to add '/' and '\0'*/
			int j;
			for(j=0; j<arg_len; j++){
				dir[j] = argv[j];
			}
			dir[j] = '/';
			dir[j+1] = '\0';
			return dir;
		}else{
			char *dir = (char *)malloc(arg_len+1);/* arg_len - 1 because we're adding '\0'*/
			int j, z;
			for(j=0; j<arg_len; j++){
				dir[j] = argv[j];
			}
			return dir;
		}
	}
	
}

char **getDirectories(int argc, char *argv[]){
	/*
	 * Helper function that returns a char* array containing the directories to be processed
	 * If unsuccessful, NULL is returned
	 */

	int i, arg_len;
	dir_count = 1; /*number of directories by default is at least 1 (i.e. current directory)*/
	file_count = 0;

	/*getting the count of the directories passed as an argument*/
	for(i=1; i<argc; i++){
		arg_len = strlen(argv[i]);

		if(arg_len>=3){/*3 becasue the shortest path that you can give to terminal is '.'*/
			if(argv[i][0] == '-' && argv[i][1] == 'I'){
				dir_count++;
				fstart++;
			}
			else
				break;
		}
		else
			break;
	}
	file_count = argc - i;
	if(file_count == 0){
		fprintf(stderr, "%s\n", USAGE); /*Invalid argument*/
		return NULL;
	}

	/*getting the count of the directories in the CPATH environment variable*/
	char *cpath = getenv("CPATH");
	int num_env_paths = 0;
	if(cpath != NULL){
		num_env_paths = getDirNum(cpath);
		dir_count += num_env_paths;
	}

	/*now we have the count of all the directories to be processed*/
	char **directories = (char **)malloc(sizeof(char *)*dir_count);
	if(directories != NULL){

		/*current directory first*/
		char *cur_dir = "./";
		directories[0] = strdup(cur_dir);

		/*directories in the argument*/
		int arg_paths = dir_count - num_env_paths;
		for(i=1; i<arg_paths; i++){
			arg_len = strlen(argv[i]);

			if(arg_len>=1){
				directories[i] = addSlash(argv[i], arg_len);
			}
		}

		/*now the directories in the environment*/
		if(cpath != NULL){
			char *token;
			char *seperator = ":";
			token = strtok(cpath, seperator);
			while(token != NULL){
				directories[i] = addSlash(token, strlen(token));
				token = strtok(NULL, seperator);
				i++;
			}
		}
	}
	return directories;
}

int getObj(char *afile, char *obj){
	/*
	 * Helper function to seperate the name of a header file from it's extention
	 * returns a char * array of the name and the extention if successful
	 * returns NULL if the file is not a header file
	 */
	int i;
	int len = strlen(afile);
	for(i=0; i<len; i++){
		if(afile[i] == '.')
			break;
	}
	i++;
	if(i == 1 || i == len){
		printf("%s\n", USAGE);
		return 0;
	}
	if(strcmp(afile+i, "cpp") == 0 || strcmp(afile+i, "cxx") == 0 || strcmp(afile+i, "cc") == 0 || strcmp(afile+i, "c++") == 0 || 
		strcmp(afile+i, "c") == 0 || strcmp(afile+i, "C") == 0 || strcmp(afile+i, "y") == 0 || strcmp(afile+i, "l") == 0){
		int j;
		for (j = 0; j < i; j++)
			obj[j] = afile[j];
		obj[j++] = 'o';
		obj[j] = '\0';
		return 1;
	}
	else{
		printf("%s\n", USAGE);
		return 0;
	}
}

void *run(){
	char *afile;
	const TSLinkedList *deps;
	while(work_q->size(work_q)){

		pthread_mutex_lock(&lock);
		active_threads--;/*thread finished doing its work*/
		pthread_mutex_unlock(&lock);

		/*now thread is either waiting for more work or if no work is left it's done and it'll terminate*/
		while(work_q->size(work_q) == 0 && active_threads > 0)
			pthread_cond_wait(&cond, &lock);

		if(work_q->remove(work_q, (void **)&afile)){
			if(the_table->get(the_table, afile, (void **)&deps)){
				if(!process(afile, deps, the_table, work_q))
					fprintf(stderr, "No such file[s]\n");

			}
		}
			
		pthread_cond_broadcast(&cond);
	}
	return NULL;
}

int main(int argc, char *argv[]){

	directories = getDirectories(argc, argv);
	if(directories != NULL){

		pthread_mutex_init(&lock, NULL);
		pthread_cond_init(&cond, NULL);

		work_q = TSUQueue_create(); /*construct the work queue*/
		if(work_q == NULL){
			fprintf(stderr, "[MALLOC FAILURE] Failed to make work queue\n");
			cleanUp();
			exit(0);
		}

		the_table = TSHashMap_create(0, 0.0); /*construct the map structure*/
		if(the_table == NULL){
			fprintf(stderr, "[MALLOC FAILURE] Failed to make the table\n");
			cleanUp();
			exit(0);
		}

		int i;
		char obj[256]; /*object file name*/

		for(i=fstart; i<argc; i++){
			if(getObj(argv[i], obj) == 0){
				cleanUp();
				exit(0);
			}else{
				const TSLinkedList *obj_deps = TSLinkedList_create();
				if(obj_deps == NULL){
					fprintf(stderr, "[MALLOC FAILURE] Failed to make dependecy list\n");
					cleanUp();
					exit(0);
				}
				char *arg = strdup(argv[i]);
				if (arg != NULL) {
					obj_deps->addLast(obj_deps, (void *)arg);
					if(!the_table->put(the_table, obj, (void *)obj_deps, NULL)){
						fprintf(stderr, "[MALLOC FAILURE] Failed to add to the table, already present\n");
					}
					const TSLinkedList *ext_deps = TSLinkedList_create();
					if(ext_deps == NULL){
						fprintf(stderr, "[MALLOC FAILURE] Failed to make dependecy list\n");
						cleanUp();
						exit(0);
					}
					if(!the_table->put(the_table, argv[i], (void *)ext_deps, NULL)){
						fprintf(stderr, "[MALLOC FAILURE] Failed to add to the table, already present\n");
					}
					work_q->add(work_q, (void *)arg);
				}
				else 
					fprintf(stderr, "[MALLOC FAILURE]\n");
			}
		}
		/*at this point, we have all the .o's, .c's, .l's, and .y's in the_table*/
		/*creating threads*/

		int nthreads = 2;
		char *CRAWLER_THREADS = getenv("CRAWLER_THREADS");
		if(CRAWLER_THREADS != NULL){
			nthreads = atoi(CRAWLER_THREADS);
			if(nthreads<1 || nthreads>50){
				fprintf(stderr, "CRAWLER_THREADS is either too large or too small (<1 or >50): %d\nUsing 2 threads\n", nthreads);
				nthreads = 2;
			}
		}

		active_threads = nthreads;
		pthread_t tids[nthreads];
		for(i=0; i<nthreads; i++)
			if(pthread_create(&tids[i], NULL, run, NULL)!=0){
				fprintf(stderr, "Failed to create threads\n");
				cleanUp();
				exit(0);
			}

		/*join threads*/
		for(i=0; i<nthreads; i++)
			if(pthread_join(tids[i], NULL) != 0)
				fprintf(stderr, "Failed to join threads\n");

		
		for(i=fstart; i<argc; i++){
			if (!getObj(argv[i], obj)) {
				cleanUp();
				exit(0);
			}

			/*create a set in which to track file names already printed*/
			const TSOrderedSet *printed = TSOrderedSet_create(scmp);
			if(printed == NULL){
				fprintf(stderr, "%s\n", "Failed to create the ordered set that holds print dependencies");
				cleanUp();
				exit(0);
			}
			/*create a linked list to track dependencies yet to print*/
			const TSLinkedList *to_be_printed = TSLinkedList_create();
			if(to_be_printed == NULL){
				fprintf(stderr, "%s\n", "Failed to create the linked list that holds to be printed dependencies");
				cleanUp();
				exit(0);
			}
			fprintf(stdout, "%s:", obj);
			printed->add(printed, (void *)obj);
			to_be_printed->addLast(to_be_printed, (void *)obj);
			printDependencies(stdout, the_table, printed, to_be_printed);
			fprintf(stdout, "\n");
			printed->destroy(printed, NULL);
			to_be_printed->destroy(to_be_printed, NULL);
		}
	}
	cleanUp();
}