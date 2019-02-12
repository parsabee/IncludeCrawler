To build and install include_crawler, after cloning the repository, run the following commands in shell:  
```
$ autoreconf -if
$ ./configure
$ make
$ sudo make install
``` 
Note that you need to have the following packages installed:  
autotools-dev  
automake  

If you're on mac use homebrew:
```
$ brew install autoconf
$ brew install automake
```
If on linux:
```
$ sudo apt-get install autoconf
$ sudo apt-get install automake
```
or similar package managers.
# Synopsis
```
Usage: include_crawler [-Idir] ... file.ext ...
```
N.B. include_crawler works on files with extentions: .c, .C, .cpp, .cxx, .c++, .cc, .y, and .l.

# Include Crawler

Implementaion by Parsa Bagheri  
Design by Prof. Joe Sventek

Large-scale systems developed in C tend to #include a large number of “.h”files, both of a system variety (enclosed in < >) and non-system (enclosed in “ ”).  Use of the make utility is a convenient way to record dependencies between source files, and to minimize the amount of work that is done when the system needs to be rebuilt.  Of course, the work will only be minimized if the Makefile exactly captures the dependencies between source and object files. Some systems are extremely large.  It is difficult to keep the dependencies in the Makefile correct as many people concurrently make changes, even using git or subversion.  Therefore, there is a need for a program that can crawl over source files, noting any#include directives, and recurse through files specified in #include directives, and finally generatethe correct dependency specifications.#include directives for system files (enclosed in < >) are normally NOT specified in make dependencies.  Therefore, our system will focus on generating dependencies between source files and non-system #include directives (enclosed in “ ”). For very large software systems, a singly-threaded application to crawl the source files may take a very long time.  This software is a concurrent include file crawler in C and C++, that exploits the concurrency features of PThreads.

# Specification

This program understands the following arguments:   
	-Idir indicates a directory to be searched for any include files encountered  
	file.ext  source file to be scanned for #include directives; ext must be .c, .C, .cpp, .cxx, .c++, .cc, .y, or .l  
	The usage string is:./include_crawler [-Idir] ... file.ext ...  
The application uses the following environment variables when it runs:  
	CRAWLER_THREADS – if this is defined, it specifies the number of worker threads that the application must create; if it is not defined, then two (2) worker threads should be created.  
	CPATH – if this is defined, it contains a list of directories separated by ‘:’; these directories are to be searched for files specified in #include directives; if it is not defined, then no additional directories are searched beyond the current directory and any specified by –Idir flags.  
For example, if CPATH is “/home/user/include:/usr/local/group/include” and if “-Ikernel” is specified on the command line, then when processing#include “x.h”x.h will be located by searching for the following files in the following order, stopping as soon as one is found.  

# Design

The concurrent version of the application naturally employs the manager/worker pattern. The Harvest Thread is often identical to the Main Thread; thus, the Main Thread is the manager. It should be possible to adjust the number of worker threads to process the accumulated work queue to speed up the processing.  
The program assumes three phases:  
	1.populate the Work Queue  
	2.process the Work Queue; for each file retrieved from the Work Queue, scan the file for #include “...” lines; if found, add the included filename to the Work Queue and update the dependency for the file being processed in the Another Structure  
	3.harvest the data in the Another Structure, printing out the results  

# Credit

Created by Parsa Bagheri  
This software uses Open Source material.  
I am grateful to the developers of noted material for their contirbutions to Open Source     
The LICENSE and Copyright information can be found in ./IncludeCrawler/src/LICENSE  
The link to the GitHub repository: https://github.com/jsventek/ADTsv2
