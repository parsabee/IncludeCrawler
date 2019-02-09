%{
   #include "i_25.h"
   #include "i_53.h"
   #include <stdio.h>
   #include <string.h>
   #include "i_03.h"
   #include "i_07.h"
   #include "i_30.h"
   #include "i_51.h"
   #include "i_12.h"
   #include "i_52.h"
   #include "i_33.h"
   #include "i_01.h"
   #include "i_10.h"
   #include "i_41.h"
   #include <ctype.h>
   #include <signal.h>
   #include <setjmp.h>
   #include <string.h>
   #include <stdlib.h>
   #include <pthread.h>

   #define TRUE  1
   #define FALSE 0

   int a_parse();
   int a_lex();
   int a_error();
   void a_init();
   int backslash();
   int follow();
   void field_split();
   static DataStackEntry dse;
   static LinkedList *vblnames = NULL;
   static TSHTable *vars2strs = NULL;
   static int lineno = 1;
   static char *infile;		/* input file name */
   static char autoprog[10240];	/* holds text of automaton */
   static char *ap;		/* pointer used by get_ch and unget_ch */
   static char **gargv;		/* global argument list */
   static int gargc;		/* global argument count */
   TSHTable *variables = NULL;
   TSHTable *topics = NULL;
   TSHTable *builtins = NULL;
   char *progname;
%}
%union {
   char *strv;
   double dblv;
   long long intv;
   unsigned long long tstampv;
   InstructionEntry *inst;
}
%token	<strv>	VAR FIELD STRING FUNCTION PROCEDURE /* tokens that malloc */
%token	<intv>	SUBSCRIBE TO WHILE IF ELSE INITIALIZATION BEHAVIOR MAP PRINT
%token	<intv>	BOOLEAN INTEGER ROWS SECS WINDOW DESTROY
%token	<intv>	BOOLDCL INTDCL REALDCL STRINGDCL TSTAMPDCL IDENTDCL SEQDCL
%token  <intv>  ITERDCL MAPDCL WINDOWDCL
%token  <intv>  ASSOCIATE WITH
%token	<dblv>	DOUBLE
%token	<tstampv> TSTAMP
%type	<strv>	variable
%type	<intv>	variabletype basictype constructedtype maptype
%type	<intv>	argumentlist winconstr
%type	<inst>	condition while end expr begin if else
%type	<inst>	statement assignment statementlist body
%right	'='
%left	OR
%left	AND
%left	'|'
%left	'&'
%left	GT GE LT LE EQ NE
%left	'+' '-'
%left	'*' '/' '%'
%left	UNARYMINUS NOT
%right	'^'
%%
automaton:        subscriptions behavior {
                     code(TRUE, STOP, NULL, "STOP");
                     YYACCEPT;
                  }
                | subscriptions declarations behavior {
                     code(TRUE, STOP, NULL, "STOP");
                     YYACCEPT;
                  }
                | subscriptions declarations initialization behavior {
                     code(TRUE, STOP, NULL, "STOP");
                     YYACCEPT;
                  }
                | subscriptions associations behavior {
                     code(TRUE, STOP, NULL, "STOP");
                     YYACCEPT;
                  }
                | subscriptions associations declarations behavior {
                     code(TRUE, STOP, NULL, "STOP");
                     YYACCEPT;
                  }
                | subscriptions associations declarations initialization behavior {
                     code(TRUE, STOP, NULL, "STOP");
                     YYACCEPT;
                  }
                | error {
                     YYABORT;
                  }
                ;
subscriptions:	  subscription
		| subscriptions subscription
		;
subscription:	  SUBSCRIBE VAR TO VAR ';' {
	            void *dummy;
                    if (! top_exist($4)) {
                      warning($4, ": non-existent topic");
                      YYABORT;
                    }
                    if (tsht_lookup(variables, $2) != NULL) {
                      warning($2, ": variable already defined");
                      YYABORT;
                    }
                    (void) tsht_insert(topics, $4, $2, &dummy);
                    (void) tsht_insert(vars2strs, $2, $4, &dummy);
                    initDSE(&dse, dEVENT, NOTASSIGN);
                    dse.value.ev_v = NULL;
                    (void) tsht_insert(variables, $2, dse_duplicate(dse), &dummy);
                }
		;
associations:     association
                | associations association
                ;
association:      ASSOCIATE VAR WITH VAR ';' {
	            void *dummy;
                    if (! ptab_exist($4)) {
                      warning($4, ": non-existent persistent table");
                      YYABORT;
                    }
                    if (tsht_lookup(variables, $2) != NULL) {
                      warning($2, ": variable already defined");
                      YYABORT;
                    }
		    initDSE(&dse, dPTABLE, NOTASSIGN);
                    dse.value.str_v = $4;
		    (void) tsht_insert(variables, $2, dse_duplicate(dse), &dummy);
                    mem_free($2);
                }
                ;
declarations:	  declaration
		| declarations declaration
		;
/* varlist is linked list of names, when this production fires, must insert
   name against struct with type and value into hash table */
declaration:	  variabletype variablelist ';' {
	            char *p;
                    void *dummy;
                    initDSE(&dse, $1, 0);
                    while ((p = (char *)ll_remove(vblnames))) {
                      if (tsht_lookup(variables, p) != NULL) {
                        warning(p, ": variable previously defined");
                        YYABORT;
                      }
                      switch(dse.type) {
                      case dBOOLEAN:	dse.value.bool_v = 0; break;
                      case dINTEGER:	dse.value.int_v = 0; break;
                      case dDOUBLE:	dse.value.dbl_v = 0; break;
                      case dTSTAMP:	dse.value.tstamp_v = 0; break;
                      case dSTRING:	dse.value.str_v = NULL; break;
                      case dMAP:	dse.value.map_v = NULL; break;
                      case dIDENT:	dse.value.str_v = NULL; break;
                      case dWINDOW:	dse.value.win_v = NULL; break;
                      case dITERATOR:	dse.value.iter_v = NULL; break;
                      case dSEQUENCE:	dse.value.seq_v = NULL; break;
                      }
                      (void)tsht_insert(variables, p, dse_duplicate(dse), &dummy);
                      mem_free(p);
                    }
                    ll_delete(vblnames); vblnames = NULL;
	          }
		;
basictype:	  INTDCL    { $$ = dINTEGER; }
	        | BOOLDCL   { $$ = dBOOLEAN; }
		| REALDCL   { $$ = dDOUBLE; }
		| STRINGDCL { $$ = dSTRING; }
		| TSTAMPDCL { $$ = dTSTAMP; }
                ;
constructedtype:  SEQDCL    { $$ = dSEQUENCE; }
		| IDENTDCL  { $$ = dIDENT; }
                | ITERDCL   { $$ = dITERATOR; }
                | MAPDCL    { $$ = dMAP; }
                | WINDOWDCL { $$ = dWINDOW; }
		;
variabletype:     basictype
                | constructedtype
                ;
maptype:          basictype
                | SEQDCL    { $$ = dSEQUENCE; }
                | WINDOWDCL { $$ = dWINDOW; }
                ;
variablelist:	  variable
		| variablelist ',' variable
		;
variable:	  VAR {
	            if (! vblnames)
                      vblnames = ll_create();
                    ll_add2tail(vblnames, (void *)$1);
                  }
		;
winconstr:        ROWS { $$ = dROWS; }
                | SECS { $$ = dSECS; }
                ;
initialization:	  INITIALIZATION '{' statementlist '}' {
	            code(TRUE, STOP, NULL, "STOP");
                  }
		;
behavior:	  BEHAVIOR { switchcode(); } '{' statementlist '}' {
	            code(TRUE, STOP, NULL, "STOP");
                    endcode();
                  }
		;
statementlist:	  statement
		| statementlist statement
		;
statement:	  ';' {
                    $$ = (InstructionEntry *)0;
                  }
		| expr ';'
                | PRINT '(' expr ')' ';' {
                     code(TRUE, print, NULL, "print");
                     $$ = $3;
                  }
                | DESTROY '(' VAR ')' ';' {
                     if (tsht_lookup(variables, $3) == NULL) {
                       warning($3, ": undefined variable");
                       YYABORT;
                     }
                     code(TRUE, destroy, NULL, "destroy");
                     initDSE(&dse, dSTRING, 0);
                     dse.value.str_v = $3;
                     code(FALSE, STOP, &dse, "variable name");
                  }
		| PROCEDURE '(' argumentlist ')' ';' {
                    if (iflog)
                      fprintf(stderr, "%s called, #args = %lld\n", $1, $3);
                    code(TRUE, procedure, NULL, "procedure");
                    initDSE(&dse, dSTRING, 0);
                    dse.value.str_v = $1;
                    code(FALSE, STOP, &dse, "procname");
                    initDSE(&dse, dINTEGER, 0);
                    dse.value.int_v = $3;
                    code(FALSE, STOP, &dse, "nargs");
                  }
		| while condition begin body end {
                    ($1)[1].type = PNTR;
                    ($1)[1].u.offset = $3 - $1;
                    ($1)[2].type = PNTR;
                    ($1)[2].u.offset = $5 - $1;
                  }
		| if condition begin body end {
                    ($1)[1].type = PNTR;
                    ($1)[1].u.offset = $3 - $1;
                    ($1)[2].type = PNTR;
                    ($1)[2].u.offset = 0;
                    ($1)[3].type = PNTR;
                    ($1)[3].u.offset = $5 - $1;
                  }
		| if condition begin body else begin body end {
                    ($1)[1].type = PNTR;
                    ($1)[1].u.offset = $3 - $1;
                    ($1)[2].type = PNTR;
                    ($1)[2].u.offset = $6 - $1;
                    ($1)[3].type = PNTR;
                    ($1)[3].u.offset = $8 - $1;
                  }
		| '{' statementlist '}' {
                    $$ = $2;
                  }
		;
body:             statement {
                    if (iflog)
                      fprintf(stderr, "Starting code generation of body\n");
                  }
                ;
argumentlist:	  /* empty */			{ $$ = 0; }
		| expr				{ $$ = 1; }
		| argumentlist ',' expr		{ $$ = $1 + 1; }
		;
assignment:	  VAR '=' expr {
                     InstructionEntry *spc;
                     if (tsht_lookup(variables, $1) == NULL) {
                       warning($1, ": undefined variable");
                       YYABORT;
                     }
                     spc = code(TRUE, varpush, NULL, "varpush");
                     initDSE(&dse, dSTRING, 0);
                     dse.value.str_v = $1;
                     code(FALSE, STOP, &dse, "variable name");
                     code(TRUE, assign, NULL, "assign");
                     $$ = $3;
                  }
		;
condition:	  '(' expr ')' {
                    code(TRUE, STOP, NULL, "end condition");
	            $$ = $2;
                  }
		;
while:		  WHILE {
                    InstructionEntry *spc;
                    if (iflog)
                      fprintf(stderr, "Starting code generation for while\n");
                    spc = code(TRUE, whilecode, NULL, "whilecode");
                    code(TRUE, STOP, NULL, "whilebody");
                    code(TRUE, STOP, NULL, "nextstatement");
                    $$ = spc;
                  }
		;
if:		  IF {
                    InstructionEntry *spc;
                    if (iflog)
                      fprintf(stderr, "Starting code generation for if\n");
                    spc = code(TRUE, ifcode, NULL, "ifcode");
                    code(TRUE, STOP, NULL, "thenpart");
                    code(TRUE, STOP, NULL, "elsepart");
                    code(TRUE, STOP, NULL, "nextstatement");
                    $$ = spc;
                  }
		;
else:		  ELSE {
                    code(TRUE, STOP, NULL, "STOP"); $$ = progp;
                  }
		;
begin:		  /* nothing */ { $$ = progp; }
		;
end:		  /* nothing */ {
                    code(TRUE, STOP, NULL, "STOP"); $$ = progp;
                  }
		;
expr:	          INTEGER {
                     code(TRUE, constpush, NULL, "constpush");
                     initDSE(&dse, dINTEGER, 0);
                     dse.value.int_v = $1;
                     $$ = code(FALSE, NULL, &dse, "integer literal");
                     //$$ = (InstructionEntry *)0;
                  }
		| DOUBLE {
                     code(TRUE, constpush, NULL, "constpush");
                     initDSE(&dse, dDOUBLE, 0);
                     dse.value.dbl_v = $1;
                     $$ = code(FALSE, NULL, &dse, "real literal");
                     //$$ = (InstructionEntry *)0;
                  }
		| BOOLEAN {
                     code(TRUE, constpush, NULL, "constpush");
                     initDSE(&dse, dBOOLEAN, 0);
                     dse.value.bool_v = $1;
                     $$ = code(FALSE, NULL, &dse, "boolean literal");
                     //$$ = (InstructionEntry *)0;
                  }
		| TSTAMP {
                     code(TRUE, constpush, NULL, "constpush");
                     initDSE(&dse, dTSTAMP, 0);
                     dse.value.tstamp_v = $1;
                     $$ = code(FALSE, NULL, &dse, "timestamp literal");
                     //$$ = (InstructionEntry *)0;
                  }
		| STRING {
                     code(TRUE, constpush, NULL, "constpush");
                     initDSE(&dse, dSTRING, 0);
                     dse.value.str_v = $1;
                     $$ = code(FALSE, NULL, &dse, "string literal");
                     //$$ = (InstructionEntry *)0;
                  }
		| VAR {
                     InstructionEntry *spc;
                     if (tsht_lookup(variables, $1) == NULL) {
                       warning($1, ": undefined variable");
                       YYABORT;
                     }
                     spc = code(TRUE, varpush, NULL, "varpush");
                     initDSE(&dse, dSTRING, 0);
                     dse.value.str_v = $1;
                     code(FALSE, STOP, &dse, "variable");
                     code(TRUE, eval, NULL, "eval");
                     $$ = spc;
                  }
		| FIELD {
                     char variable[1024], field[1024], *st;
                     int ndx;
                     InstructionEntry *spc;
                     field_split($1, variable, field);
                     if ((st = (char *)tsht_lookup(vars2strs, variable)) == NULL) {
                       warning(variable, ": unknown event variable");
                       YYABORT;
                     }
                     if ((ndx = top_index(st, field)) == -1) {
                       warning(field, ": illegal field name");
                       YYABORT;
                     }
                     spc = code(TRUE, varpush, NULL, "varpush");
                     initDSE(&dse, dSTRING, 0);
                     dse.value.str_v = str_dupl(variable);
                     code(FALSE, STOP, &dse, "event variable");
                     code(TRUE, constpush, NULL, "constpush");
                     initDSE(&dse, dINTEGER, 0);
                     dse.value.int_v = ndx;
                     code(FALSE, STOP, &dse, "index");
                     code(TRUE, extract, NULL, "extract");
                     mem_free($1);
                     $$ = spc;
                  }
		| assignment
                | MAP '(' maptype ')' {
                    code(TRUE, newmap, NULL, "Map");
                    initDSE(&dse, dINTEGER, 0);
                    dse.value.int_v = $3;
                    code(FALSE, STOP, &dse, "map type");
                  }
                | WINDOW '(' basictype ',' winconstr ',' INTEGER ')' {
                    code(TRUE, newwindow, NULL, "Window");
                    initDSE(&dse, dINTEGER, 0);
                    dse.value.int_v = $3;
                    code(FALSE, STOP, &dse, "window type");
                    initDSE(&dse, dINTEGER, 0);
                    dse.value.int_v = $5;
                    code(FALSE, STOP, &dse, "constraint type");
                    initDSE(&dse, dINTEGER, 0);
                    dse.value.int_v = $7;
                    code(FALSE, STOP, &dse, "constraint size");
                  }
		| FUNCTION '(' argumentlist ')' {
                    if (iflog)
                      fprintf(stderr, "%s called, #args = %lld\n", $1, $3);
                    code(TRUE, function, NULL, "function");
                    initDSE(&dse, dSTRING, 0);
                    dse.value.str_v = $1;
                    code(FALSE, STOP, &dse, "procname");
                    initDSE(&dse, dINTEGER, 0);
                    dse.value.int_v = $3;
                    code(FALSE, STOP, &dse, "nargs");
                  }
		| '(' expr ')' {
                    $$ = $2;
                  }
		| expr '+' expr {
                     $$ = code(TRUE, add, NULL, "add");
                  }
		| expr '-' expr {
                     $$ = code(TRUE, subtract, NULL, "subtract");
                  }
		| expr '*' expr {
                     $$ = code(TRUE, multiply, NULL, "multiply");
                  }
		| expr '/' expr {
                     $$ = code(TRUE, divide, NULL, "divide");
                  }
		| expr '%' expr {
                     $$ = code(TRUE, modulo, NULL, "modulo");
                  }
		| expr '|' expr {
                     $$ = code(TRUE, bitOr, NULL, "bitOr");
                  }
		| expr '&' expr {
                     $$ = code(TRUE, bitAnd, NULL, "bitAnd");
                  }
		| '-' expr %prec UNARYMINUS {
                     $$ = code(TRUE, negate, NULL, "negate");
                  }
		| expr GT expr { $$ = code(TRUE, gt, NULL, "gt"); }
		| expr GE expr { $$ = code(TRUE, ge, NULL, "ge"); }
		| expr LT expr { $$ = code(TRUE, lt, NULL, "lt"); }
		| expr LE expr { $$ = code(TRUE, le, NULL, "le"); }
		| expr EQ expr { $$ = code(TRUE, eq, NULL, "eq"); }
		| expr NE expr { $$ = code(TRUE, ne, NULL, "ne"); }
		| expr AND expr { $$ = code(TRUE, and, NULL, "and"); }
		| expr OR expr { $$ = code(TRUE, or, NULL, "or"); }
		| NOT expr { $$ = code(TRUE, not, NULL, "not"); }
		;
%%

struct fpstruct {
   char *name;
   unsigned int min, max, index;
};

static struct fpstruct functions[] = {
   {"float", 1, 1, 0},		    /* real float(int) */
   {"Identifier", 1, MAX_ARGS, 1},  /* identifier Identifier(arg[, ...]) */
   {"lookup", 2, 2, 2},		    /* map.type lookup(map, identifier) */
   {"average", 1, 1, 3},	    /* real average(window) */
   {"stdDev", 1, 1, 4},		    /* real stdDev(window) */
   {"currentTopic", 0, 0, 5},	    /* string currentTopic() */
   {"Iterator", 1, 1, 6},  	    /* iterator Iterator(map|win|seq) */
   {"next", 1, 1, 7},    	    /* identifier|data next(iterator) */
   {"tstampNow", 0, 0, 8},	    /* tstamp tstampNow() */
   {"tstampDelta", 3, 3, 9},	    /* tstamp tstampDelta(tstamp, int, bool) */
   {"tstampDiff", 2, 2, 10},	    /* int tstampDiff(tstamp, tstamp) */
   {"Timestamp", 1, 1, 11}, 	    /* tstamp Timestamp(string) */
   {"dayInWeek", 1, 1, 12},	    /* int dayInWeek(tstamp) [Sun/0,Sat/6] */
   {"hourInDay", 1, 1, 13},	    /* int hourInDay(tstamp) [0..23] */
   {"dayInMonth", 1, 1, 14},	    /* int dayInMonth(tstamp) [1..31] */
   {"Sequence", 0, MAX_ARGS, 15},   /* sequence Sequence([arg[, ...]]) */
   {"hasEntry", 2, 2, 16},          /* bool hasEntry(map, identifier) */
   {"hasNext", 1, 1, 17},           /* bool hasNext(iterator) */
   {"String", 1, MAX_ARGS, 18},     /* string String(arg[, ...]) */
   {"seqElement", 2, 2, 19},        /* basictype seqElement(seq, int) */
   {"seqSize", 1, 1, 20},           /* int seqSize(seq) */
   {"IP4Addr", 1, 1, 21},           /* int IP4Addr(string) */
   {"IP4Mask", 1, 1, 22},           /* int IP4Mask(int) */
   {"matchNetwork", 3, 3, 23},      /* bool matchNetwork(string, int, int) */
   {"secondInMinute", 1, 1, 24},    /* int secondInMinute(tstamp) [0..60] */
   {"minuteInHour", 1, 1, 25},      /* int minuteInHour(tstamp) [0..59] */
   {"monthInYear", 1, 1, 26},       /* int monthInYear(tstamp) [1..12] */
   {"yearIn", 1, 1, 27}             /* int yearIn(tstamp) [1900 .. ] */
};
#define NFUNCTIONS (sizeof(functions)/sizeof(struct fpstruct))
static struct fpstruct procedures[] = {
   {"topOfHeap", 0, 0, 0},     /* void topOfHeap() */
   {"insert", 3, 3, 1},	       /* void insert(map, ident, map.type) */
   {"remove", 2, 2, 2},	       /* void remove(map, ident) */
   {"send", 1, MAX_ARGS, 3},   /* void send(arg, ...) */
   {"append", 2, MAX_ARGS, 4}, /* void append(window, window.dtype[, tstamp]) */
                               /* if wtype == SECS, must provide tstamp */
                               /* void append(sequence, basictype[, ...]) */
   {"publish", 2, MAX_ARGS, 5} /* void publish(topic, arg, ...) */
};
#define NPROCEDURES (sizeof(procedures)/sizeof(struct fpstruct))

struct keyval {
    char *key;
    int value;
};

static struct keyval keywords[] = {
	{"subscribe", SUBSCRIBE},
	{"to", TO},
	{"associate", ASSOCIATE},
	{"with", WITH},
        {"bool", BOOLDCL},
	{"int", INTDCL},
	{"real", REALDCL},
	{"string", STRINGDCL},
	{"tstamp", TSTAMPDCL},
        {"sequence", SEQDCL},
        {"iterator", ITERDCL},
        {"map", MAPDCL},
        {"window", WINDOWDCL},
	{"identifier", IDENTDCL},
	{"if", IF},
	{"else", ELSE},
	{"while", WHILE},
	{"initialization", INITIALIZATION},
	{"behavior", BEHAVIOR},
	{"Map", MAP},
        {"Window", WINDOW},
        {"destroy", DESTROY},
        {"ROWS", ROWS},
        {"SECS", SECS}
};
#define NKEYWORDS sizeof(keywords)/sizeof(struct keyval)

int get_ch(char **ptr) {
   char *p = *ptr;
   int c = *p;
   if (c)
      p++;
   else
      c = EOF;
   *ptr = p;
   return c;
}

void unget_ch(int c, char **ptr) {
   char *p = *ptr;
   *(--p) = c;
   *ptr = p;
}

int a_lex() {
   int c;
top:
    while ((c = get_ch(&ap)) == ' ' || c == '\t' || c == '\n')
        if (c == '\n')
            lineno++;
    if (c == '#') { 		/* comment to end of line */
        while ((c = get_ch(&ap)) != '\n' && c != EOF)
           ;			/* consume rest of line */
        if (c == '\n') {
            lineno++;
            goto top;
        }
    }
    if (c == EOF)
        return 0;
    if (c == '.' || isdigit(c)) {	/* a number */
        char buf[128], *p;
        double d;
        long l;
        int isfloat = 0;
        int retval;
        p = buf;
        do {
            if (c == '.')
                isfloat++;
            *p++ = c;
            c = get_ch(&ap);
        } while (isdigit(c) || c == '.');
        unget_ch(c, &ap);
        *p = '\0';
        if (isfloat) {
            sscanf(buf, "%lf", &d);
            a_lval.dblv = d;
            retval = DOUBLE;
        } else {
            sscanf(buf, "%ld", &l);
            a_lval.intv = l;
            retval = INTEGER;
        }
        return retval;
    }
    if (c == '@') {	/* timestamp literal */
        char buf[20], *p;
        int n = 16;
        p = buf;
        *p++ = c;
        while (n > 0) {
            c = get_ch(&ap);
            if (! isxdigit(c))
                execerror("syntactically incorrect timestamp", NULL);
            *p++ = c;
            n--;
        }
        c = get_ch(&ap);
        if(c != '@')
            execerror("syntactically incorrect timestamp", NULL);
        *p++ = c;
        *p = '\0';
        a_lval.tstampv = string_to_timestamp(buf);
        return TSTAMP;
    }
    if (isalpha(c)) {
        char sbuf[100], *p = sbuf;
	unsigned int i;
        int isfield = 0;

        do {
            if (p >= sbuf + sizeof(sbuf) - 1) {
                *p = '\0';
                execerror("name too long", sbuf);
            }
            *p++ = c;
            if (c == '.')
                isfield++;
        } while ((c = get_ch(&ap)) != EOF && (isalnum(c) || c == '.' || c == '_'));
        unget_ch(c, &ap);
        *p = '\0';
	for (i = 0; i < NFUNCTIONS; i++) {
            if (strcmp(sbuf, functions[i].name) == 0) {
                a_lval.strv = str_dupl(sbuf);
                return (FUNCTION);
            }
        }
	for (i = 0; i < NPROCEDURES; i++) {
            if (strcmp(sbuf, procedures[i].name) == 0) {
                a_lval.strv = str_dupl(sbuf);
                return (PROCEDURE);
            }
        }
        if (strcmp(sbuf, "true") == 0) {
            a_lval.intv = 1;
            return (BOOLEAN);
        } else if (strcmp(sbuf, "false") == 0) {
            a_lval.intv = 0;
            return (BOOLEAN);
        }
	for (i = 0; i < NKEYWORDS; i++) {
            if (strcmp(sbuf, keywords[i].key) == 0) {
                return (keywords[i].value);
            }
        }
        if (strcmp(sbuf, "print") == 0)
            return PRINT;
        a_lval.strv = str_dupl(sbuf);
        if (isfield)
            return FIELD;
        else
            return VAR;
    }
    if (c == '\'') {		/* quoted string */
        char sbuf[100], *p;
        for (p = sbuf; (c = get_ch(&ap)) != '\''; p++) {
            if (c == '\n' || c == EOF)
                execerror("missing quote", NULL);
            if (p >= sbuf + sizeof(sbuf) - 1) {
                *p = '\0';
                execerror("string too long", sbuf);
            }
            *p = backslash(c);
        }
        *p = '\0';
        a_lval.strv = str_dupl(sbuf);
        return STRING;
    }
    switch (c) {
        case '>':	return follow('=', GE, GT);
        case '<':	return follow('=', LE, LT);
        case '=':	return follow('=', EQ, '=');
        case '!':	return follow('=', NE, NOT);
        case '|':	return follow('|', OR, '|');
        case '&':	return follow('&', AND, '&');
        case '\n':	lineno++; return '\n';
	default:	return c;
    }
}

int backslash(int c) {		/* get next character with \'s interpreted */
    static char transtab[] = "b\bf\fn\nr\rt\t";
    if (c != '\\')
        return c;
    c = get_ch(&ap);
    if (islower(c) && strchr(transtab, c))
        return strchr(transtab, c)[1];
    return c;
}

void field_split(char *token, char *variable, char *field) {
    char *p, *q;
    p = token;
    for (q = variable; *p != '\0'; ) {
        if (*p == '.')
            break;
        *q++ = *p++;
    }
    *q = '\0';
    strcpy(field, (*p == '.') ? ++p : p);
}

int follow(int expect, int ifyes, int ifno) {	/* look ahead for >=, ... */
    int c = get_ch(&ap);
    if (c == expect)
        return ifyes;
    unget_ch(c, &ap);
    return ifno;
}

int a_error(char *s) {		/* report compile-time error */
    warning(s, (char *)0);
    return 1;
}

void a_init(void) {
    unsigned int i;
    topics = tsht_create(25L);
/* really should check if this is non-null, and if so, return storage */
    if (! vars2strs) {
        vars2strs = tsht_create(25L);
    } else {
        char **keys;
        void *s;
        unsigned long i, n = tsht_keys(vars2strs, &keys);
        for (i = 0; i < n; i++) {
            (void) tsht_remove(vars2strs, keys[i], &s);
            mem_free(s);
        }
        mem_free(keys);
    }
    variables = tsht_create(25L);
    if (! builtins) {
        builtins = tsht_create(25L);
        for (i = 0; i < NFUNCTIONS; i++) {
            struct fpargs *d = (struct fpargs *)mem_alloc(sizeof(struct fpargs));
            void *dummy;
            if (d) {
                d->min = functions[i].min;
                d->max = functions[i].max;
                d->index = functions[i].index;
                (void)tsht_insert(builtins, functions[i].name, d, &dummy);
            }
        }
        for (i = 0; i < NPROCEDURES; i++) {
            struct fpargs *d = (struct fpargs *)mem_alloc(sizeof(struct fpargs));
            void *dummy;
            if (d) {
                d->min = procedures[i].min;
                d->max = procedures[i].max;
                d->index = procedures[i].index;
                (void)tsht_insert(builtins, procedures[i].name, d, &dummy);
            }
        }
    }
}

void ap_init(char *prog) {
   strcpy(autoprog, prog);
   ap = autoprog;
}

void execerror(char *s, char *t) {	/* recover from run-time error */
    char buf[1024];
    jmp_buf *begin = (jmp_buf *)pthread_getspecific(jmpbuf_key);
    warning(s, t);
    sprintf(buf, "%s %s", s, t);
    (void) pthread_setspecific(execerr_key, (void *)str_dupl(buf));
    longjmp(*begin, -2);
}

void fpecatch(int __attribute__ ((unused)) signum) { /* catch FP exceptions */
    execerror("floating point exception", (char *)0);
}

static int pack(char *file, char *program) {
   FILE *fp;

   if ((fp = fopen(file, "r")) != NULL) {
      int c;
      char *p = program;
      while ((c = fgetc(fp)) != EOF) {
         *p++ = c;
      }
      *p = '\0';
      fclose(fp);
      return 1;
   }
   return 0;
}

int moreinput(void) {
    if (gargc-- <= 0)
        return 0;
    infile= *gargv++;
    lineno = 1;
    if (! pack(infile, autoprog)) {
        fprintf(stderr, "%s: can't open %s\n", progname, infile);
        return moreinput();
    }
    ap = autoprog;
    return 1;
}


void warning(char *s, char *t) {		/* print warning message */
    fprintf(stderr, "%s: %s", progname, s);
    if (t)
        fprintf(stderr, " %s", t);
    if (infile)
        fprintf(stderr, " in %s", infile);
    fprintf(stderr, " near line %d\n", lineno);
}
