%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "i_60.h"
#include "i_51.h"
#include "i_45.h"
#include "i_28.h"
#include "i_56.h"
#include "i_33.h"

extern int yylex();

void yyerror(const char *str)
{
        fprintf(stderr,"error: %s\n",str);
}
 
int yywrap()
{
        return 1;
}

/* SQL statement to be returned after parsing */
extern sqlstmt stmt;

/* Temporary lists used while parsing */

/* Select */
List *clist;
List *cattriblist;
List *tlist;
List *flist;
List *wlist;
List *plist; /* pair list */
sqlwindow *tmpwin;
int tmpunit;
sqlfilter *tmpfilter;
sqlpair *tmppair;
int tmpvaltype;
char *tmpvalstr;
int filtertype;
char *orderby;
int countstar;
List *grouplist;
sqlinterval tmpinterval;

/* Create */
char *tablename;
List *colnames;
List *coltypes;
short tabletype;
short primary_column;
short column;

/* Insert */
/* -- tablename definition from above */
/* -- coltypes definition from above */
List *colvals;
short transform;

%}

%union 
{
    long long number;
    double numfloat;
    char character;
    char *string;
    unsigned long long tstamp;
}

/*%token <number> NUMBER
%token <numfloat> NUMFLOAT
*/
%token <string> NUMBER
%token <string> NUMFLOAT
%token <string> TSTAMP
%token <string> DATESTRING
%token <string> WORD
%token <string> QUOTEDSTRING
%token <string> IPADDR
/*%token <string> PORT*/

%token SELECT FROM WHERE LESSEQ GREATEREQ LESS GREATER EQUALS COMMA STAR 
%token SEMICOLON CREATE INSERT TABLETK OPENBRKT CLOSEBRKT TABLE INTO VALUES
%token BOOLEAN INTEGER REAL CHARACTER VARCHAR BLOB TINYINT SMALLINT
%token TRUETK FALSETK SINGLEQUOTE PRIMARY KEY
%token OPENSQBRKT CLOSESQBRKT MILLIS SECONDS MINUTES HOURS RANGE SINCE INTERVAL NOW ROWS LAST
%token SHOW TABLES AND OR
%token SAVE AS EXEC DELETE QUERY
%token COUNT MIN MAX AVG SUM
%token ORDER BY
%token PUBLISH SUBSCRIBE UNSUBSCRIBE REGISTER UNREGISTER
%token PERSISTENTTABLETK
%token GROUP
%token UPDATE SET ADD SUB ON DUPLICATETK
%token CONTAINS NOTCONTAINS

%type <string> tstamp_expression

%%

top: sqlStmt {
		YYACCEPT;
	}
	| error {
		YYABORT;
	}
	;
sqlStmt:
	EXEC WORD {
		debugvf("Executing saved Select statment: %s\n", (char *)$2);
		stmt.type = SQL_TYPE_EXEC_SAVED_SELECT;
		stmt.name = (char *)$2;
	}
	| DELETE QUERY WORD {
		debugvf("Deleting query %s\n", (char*)$3);
		stmt.type = SQL_TYPE_DELETE_QUERY;
		stmt.name = (char*)$3;
	}
	| SAVE OPENBRKT selectStmt CLOSEBRKT AS WORD {
		
		debugvf("Saving a Select statment as: %s.\n", (char *)$6);		
		stmt.type = SQL_TYPE_SAVE_SELECT;
		
		/* Store the save-as name */
		stmt.name = (char *)$6;
		
		/* Columns */
		stmt.sql.select.ncols =  list_len(clist);
		stmt.sql.select.cols = (char **) list_to_array(clist);
		list_free(clist);
		clist=NULL;
		
		/* Column attribs (count, min, max, avg, sum) */
		stmt.sql.select.colattrib = (int **) list_to_array(cattriblist);
		list_free(cattriblist);
		cattriblist = NULL;
		
		/* From Tables */
		stmt.sql.select.ntables = list_len(tlist);
		stmt.sql.select.tables = (char **) list_to_array(tlist);
		list_free(tlist);
		tlist=NULL;
		
		/* Table windows */
		if (wlist) {
			stmt.sql.select.windows = (sqlwindow **) list_to_array(wlist);
			list_free(wlist);
			wlist=NULL;
		}
		
		/* Where filters */
		if (flist) {
			stmt.sql.select.nfilters = list_len(flist);
			stmt.sql.select.filters = (sqlfilter **) list_to_array(flist);
			stmt.sql.select.filtertype = filtertype;
			list_free(flist);
			flist=NULL;
		}
		
		/* Order by */
		if (orderby) {
			stmt.sql.select.orderby = orderby;
		} else {
			stmt.sql.select.orderby = NULL;
		}
		
		/* Count(*) ? */
		if (countstar) {
			debugvf("Is count(*)\n");
			stmt.sql.select.isCountStar = 1;
		} else {
			debugvf("Not count(*)\n");
			stmt.sql.select.isCountStar = 0;
		}
		
	}
	| selectStmt {
	
		debugvf("Select statment.\n");
		stmt.type = SQL_TYPE_SELECT;
		
		/* Columns */
		stmt.sql.select.ncols =  list_len(clist);
		stmt.sql.select.cols = (char **) list_to_array(clist);
		list_free(clist);
		clist=NULL;
		
		/* Column attribs (count, min, max, avg, sum) */
		stmt.sql.select.colattrib = (int **) list_to_array(cattriblist);
		list_free(cattriblist);
		cattriblist = NULL;
		
		/* From Tables */
		stmt.sql.select.ntables = list_len(tlist);
		stmt.sql.select.tables = (char **) list_to_array(tlist);
		list_free(tlist);
		tlist=NULL;
		
		/* Table windows */
		if (wlist) {
			stmt.sql.select.windows = (sqlwindow **) list_to_array(wlist);
			list_free(wlist);
			wlist=NULL;
		}
		
		/* Where filters */
		if (flist) {
			stmt.sql.select.nfilters = list_len(flist);
			stmt.sql.select.filters = (sqlfilter **) list_to_array(flist);
			stmt.sql.select.filtertype = filtertype;
			list_free(flist);
			flist=NULL;
		}
	
		/* Order by */
		if (orderby) {
			stmt.sql.select.orderby = orderby;
		} else {
			stmt.sql.select.orderby = NULL;
		}
		
		/* Count(*) ? */
		if (countstar) {
			debugvf("Is count(*)\n");
			stmt.sql.select.isCountStar = 1;
		} else {
			debugvf("Not count(*)\n");
			stmt.sql.select.isCountStar = 0;
		}

		/* Group by */
		if (grouplist) {
			stmt.sql.select.groupby_ncols =  list_len(grouplist);
			stmt.sql.select.groupby_cols = (char **) list_to_array(grouplist);
			list_free(grouplist);
			grouplist=NULL;
		} else {
			stmt.sql.select.groupby_ncols = 0;
			stmt.sql.select.groupby_cols = NULL;
		}
	}
	| createStmt {
		
		debugvf("Create statement.\n");
		stmt.type = SQL_TYPE_CREATE;
		
		stmt.sql.create.tablename = tablename;
		stmt.sql.create.ncols = list_len(colnames);
		stmt.sql.create.colname = (char **) list_to_array(colnames);
		stmt.sql.create.coltype = (int **) list_to_array(coltypes);
		list_free(colnames);
		colnames=NULL;
		list_free(coltypes);
		coltypes=NULL;
		stmt.sql.create.tabletype = tabletype;
		stmt.sql.create.primary_column = primary_column;
	}
	| insertStmt {
		
		debugvf("Insert statement.\n");
		stmt.type = SQL_TYPE_INSERT;
		
		stmt.sql.insert.tablename = tablename;
		stmt.sql.insert.ncols = list_len(colvals);
		stmt.sql.insert.colval = (char **) list_to_array(colvals);
		stmt.sql.insert.coltype = (int **) list_to_array(coltypes);
		stmt.sql.insert.transform = transform;
		list_free(colvals);
		colvals=NULL;
		list_free(coltypes);
		coltypes=NULL;
	}
	| updateStmt {
		
		debugvf("Update statement.\n");
		stmt.type = SQL_TYPE_UPDATE;
		stmt.sql.update.tablename = tablename;
		/* Set pairs */
		if (plist) {
			stmt.sql.update.npairs = list_len(plist);
			stmt.sql.update.pairs = (sqlpair **) list_to_array(plist);
			list_free(plist);
			plist=NULL;
		}
		/* Where filters */
		if (flist) {
			stmt.sql.update.nfilters = list_len(flist);
			stmt.sql.update.filters = (sqlfilter **) list_to_array(flist);
			stmt.sql.update.filtertype = filtertype;
			list_free(flist);
			flist=NULL;
		}
	}
	| SHOW TABLES {
		
		debugvf("Show tables.\n");
		stmt.type = SQL_SHOW_TABLES;
		
	}
	| PUBLISH WORD {
		
		debugvf("Publish saved query: %s\n", $2);
		
		stmt.type = SQL_TYPE_PUBLISH;
		stmt.name = $2;
		
	}
	| SUBSCRIBE WORD IPADDR NUMBER WORD {
		
		debugvf("Subscribe statement: query: %s; ip:port:service: %s:%s:%s\n", 
			(char*)$2,(char*)$3,(char*)$4,(char*)$5);
		stmt.type = SQL_TYPE_SUBSCRIBE;
		stmt.sql.subscribe.queryname = $2;
		stmt.sql.subscribe.ipaddr = $3;
		stmt.sql.subscribe.port = $4;
		stmt.sql.subscribe.service = $5;
	}
	| UNSUBSCRIBE WORD IPADDR NUMBER WORD {
		
		debugvf("Unsubscribe statement: query: %s; ip:port:service: %s:%s:%s\n", 
			(char*)$2,(char*)$3,(char*)$4,(char*)$5);
		stmt.type = SQL_TYPE_UNSUBSCRIBE;
		stmt.sql.subscribe.queryname = $2;
		stmt.sql.subscribe.ipaddr = $3;
		stmt.sql.subscribe.port = $4;
		stmt.sql.subscribe.service = $5;
	}
	| REGISTER QUOTEDSTRING IPADDR NUMBER WORD {
		
		debugvf("Register statement: automaton: %s\nip:port:service: %s:%s:%s\n", 
			(char*)$2,(char*)$3,(char*)$4,(char*)$5);
		stmt.type = SQL_TYPE_REGISTER;
		stmt.sql.regist.automaton = $2;
		stmt.sql.regist.ipaddr = $3;
		stmt.sql.regist.port = $4;
		stmt.sql.regist.service = $5;
	}
	| UNREGISTER NUMBER {
		
		debugvf("Unregister statement: automaton id: %s\n", (char *)$2);
		stmt.type = SQL_TYPE_UNREGISTER;
		stmt.sql.unregist.id = $2;
	}
	;

selectStmt:
	SELECT all FROM tableList { orderby = NULL;}
	| SELECT all FROM tableList WHERE filterList {orderby = NULL;}
	| SELECT all FROM tableList ORDER BY orderList
	| SELECT all FROM tableList WHERE filterList ORDER BY orderList
	| SELECT colList FROM tableList { orderby = NULL; countstar = 0; }
	| SELECT colList FROM tableList WHERE filterList { orderby = NULL; countstar = 0;}
	| SELECT colList FROM tableList ORDER BY orderList {countstar = 0;}
	| SELECT colList FROM tableList WHERE filterList ORDER BY orderList {countstar = 0;}
	| SELECT colList FROM tableList GROUP BY groupList {orderby = NULL; countstar = 0;}
	| SELECT colList FROM tableList WHERE filterList GROUP BY groupList 
	{orderby = NULL; countstar = 0;}
	| SELECT colList FROM tableList WHERE filterList GROUP BY groupList ORDER BY orderList
	{countstar = 0;}
	;

colList:
	col 
	| colList COMMA col
	;

col:
	WORD {
		debugvf("Col: %s\n", (char *)$1);
		if (!clist)
			clist = list_new();
		list_append(clist, (void *)$1);
		
		if (!cattriblist)
			cattriblist = list_new();
		list_append(cattriblist, (void *)SQL_COLATTRIB_NONE);
	}
	/*| COUNT OPENBRKT WORD CLOSEBRKT {
		debugvf("Col (COUNT): %s\n", (char *)$3);
		if (!clist)
			clist = list_new();
		list_append(clist, (void *)$3);
		
		if (!cattriblist)
			cattriblist = list_new();
		list_append(cattriblist, (void *)SQL_COLATTRIB_COUNT);
	} */
	| MIN OPENBRKT WORD CLOSEBRKT {
		debugvf("Col (MIN): %s\n", (char *)$3);
		if (!clist)
			clist = list_new();
		list_append(clist, (void *)$3);
		
		if (!cattriblist)
			cattriblist = list_new();
		list_append(cattriblist, (void *)SQL_COLATTRIB_MIN);
		stmt.sql.select.containsMinMaxAvgSum = 1;
	}
	| MAX OPENBRKT WORD CLOSEBRKT {
		debugvf("Col (MAX): %s\n", (char *)$3);
		if (!clist)
			clist = list_new();
		list_append(clist, (void *)$3);
		
		if (!cattriblist)
			cattriblist = list_new();
		list_append(cattriblist, (void *)SQL_COLATTRIB_MAX);
		stmt.sql.select.containsMinMaxAvgSum = 1;
	}
	| AVG OPENBRKT WORD CLOSEBRKT {
		debugvf("Col (AVG): %s\n", (char *)$3);
		if (!clist)
			clist = list_new();
		list_append(clist, (void *)$3);
		
		if (!cattriblist)
			cattriblist = list_new();
		list_append(cattriblist, (void *)SQL_COLATTRIB_AVG);
		stmt.sql.select.containsMinMaxAvgSum = 1;
	}
	| SUM OPENBRKT WORD CLOSEBRKT {
		debugvf("Col (SUM): %s\n", (char *)$3);
		if (!clist)
			clist = list_new();
		list_append(clist, (void *)$3);
		
		if (!cattriblist)
			cattriblist = list_new();
		list_append(cattriblist, (void *)SQL_COLATTRIB_SUM);
		stmt.sql.select.containsMinMaxAvgSum = 1;
	}
	;

all:
	STAR {
		debugvf("Select *\n");
		if (!clist)
			clist = list_new();
		list_append(clist, str_dupl("*"));
		if (!cattriblist)
			cattriblist = list_new();
		list_append(cattriblist, (void *)SQL_COLATTRIB_NONE);
		countstar = 0;
	}
	| COUNT OPENBRKT STAR CLOSEBRKT {
		debugvf("Select count(*)\n");
		if (!clist)
			clist = list_new();
		list_append(clist, str_dupl("*"));
		if (!cattriblist)
			cattriblist = list_new();
		list_append(cattriblist, (void *)SQL_COLATTRIB_COUNT);
		countstar = 1;
	}
	;

tableList:
	table
	| tableList COMMA table
	;

table:
	WORD {
		debugvf("Table: %s\n", (char *)$1);
		if (!tlist)
			tlist = list_new();
		list_append(tlist, (void *)$1);
		
		/* Add empty stub window */
		if (!wlist)
			wlist = list_new();
		tmpwin = sqlstmt_new_stubwindow();
		list_append(wlist, (void *)tmpwin);
	}
	| WORD OPENSQBRKT window CLOSESQBRKT {
		debugvf("Table with window: %s\n", (char*)$1);
		if (!tlist)
			tlist = list_new();
		list_append(tlist, (void *)$1);
		
		/* Add window */
		if (!wlist)
			wlist = list_new();
		list_append(wlist, (void *)tmpwin);
	}
	;

window:
	timewindow
	| tplwindow
	;

timewindow:
	NOW {
		debugvf("TimeWindow NOW\n");
		tmpwin = sqlstmt_new_timewindow_now();
	}
	| RANGE NUMBER unit {
		debugvf("TimeWindow Range %d, unit:%d\n", atoi($2), tmpunit);
		tmpwin = sqlstmt_new_timewindow(atoi($2), tmpunit);
		/* NB: memory leak. need to free $2 */
		mem_free($2);
	}
	| SINCE tstamp_expression {
		debugvf("TimeWindow Since %s\n", $2);
		tmpwin = sqlstmt_new_timewindow_since($2);
		mem_free($2);
	}
	| INTERVAL interval_expression {
		debugvf("Timewindow Interval\n");
		tmpwin = sqlstmt_new_timewindow_interval(&tmpinterval);
	}
	;

tstamp_expression:
	TSTAMP {
		debugvf("tstamp expression: %s\n", $1);
		$$ = $1;
	}
	| DATESTRING {
		tstamp_t tmp;
		debugvf("datestring expression: %s\n", $1);
		tmp = datestring_to_timestamp($1);
		$$ = timestamp_to_string(tmp);
		mem_free($1);
	}
	;

interval_expression:
	OPENBRKT tstamp_expression COMMA tstamp_expression CLOSEBRKT {
		tmpinterval.leftOp = GREATER;
		tmpinterval.rightOp = LESS;
		tmpinterval.leftTs = string_to_timestamp($2);
		tmpinterval.rightTs = string_to_timestamp($4);
		mem_free($2);
		mem_free($4);
	}
	| OPENBRKT tstamp_expression COMMA tstamp_expression CLOSESQBRKT {
		tmpinterval.leftOp = GREATER;
		tmpinterval.rightOp = LESSEQ;
		tmpinterval.leftTs = string_to_timestamp($2);
		tmpinterval.rightTs = string_to_timestamp($4);
		mem_free($2);
		mem_free($4);
	}
	| OPENSQBRKT tstamp_expression COMMA tstamp_expression CLOSEBRKT {
		tmpinterval.leftOp = GREATEREQ;
		tmpinterval.rightOp = LESS;
		tmpinterval.leftTs = string_to_timestamp($2);
		tmpinterval.rightTs = string_to_timestamp($4);
		mem_free($2);
		mem_free($4);
	}
	| OPENSQBRKT tstamp_expression COMMA tstamp_expression CLOSESQBRKT {
		tmpinterval.leftOp = GREATEREQ;
		tmpinterval.rightOp = LESSEQ;
		tmpinterval.leftTs = string_to_timestamp($2);
		tmpinterval.rightTs = string_to_timestamp($4);
		mem_free($2);
		mem_free($4);
	}
	;

unit:
    	MILLIS {
		debugvf("TimeWindow unit MILLIS\n");
		tmpunit = SQL_WINTYPE_TIME_MILLIS;
	}
	| SECONDS {
		debugvf("TimeWindow unit SECONDS\n");
		tmpunit = SQL_WINTYPE_TIME_SECONDS;
	}
	| MINUTES {
		debugvf("TimeWindow unit MINUTES\n");
		tmpunit = SQL_WINTYPE_TIME_MINUTES;
	}
	| HOURS {
		debugvf("TimeWindow unit HOURS\n");
		tmpunit = SQL_WINTYPE_TIME_HOURS;
	}
	;

tplwindow:
	ROWS NUMBER {
		debugvf("TupleWindow ROWS %d\n", atoi($2));
		tmpwin = sqlstmt_new_tuplewindow(atoi($2));
		/* NB: memory leak. need to free $2 */
		mem_free($2);
	}
	| LAST {
		debugvf("TupleWindow LAST\n");
		tmpwin = sqlstmt_new_tuplewindow(1);
	}
	;

filterList:
	filter
	| filterList AND filter {
		debugvf("Filter type: AND\n");
		filtertype = SQL_FILTER_TYPE_AND;
	}
	| filterList OR filter {
		debugvf("Filter type: OR\n");
		filtertype = SQL_FILTER_TYPE_OR;
	}
	;

pairList:
	pair
	| pairList COMMA pair {
		debugvf("Pair separator: COMMA\n");
	}
	;

pair:
	WORD EQUALS constant {
		debugvf("Pair (WORD=constant): %s = %s\n", (char *)$1, tmpvalstr);
		if (!plist)
			plist = list_new();
		tmppair = sqlstmt_new_pair(EQUALS, (char*)$1, tmpvaltype, tmpvalstr);
		list_append(plist, (void *)tmppair);
		mem_free(tmpvalstr);
	}
	| WORD ADD constant {
		debugvf("Pair (WORD+=constant): %s += %s\n", (char *)$1, tmpvalstr);
		if (!plist)
			plist = list_new();
		tmppair = sqlstmt_new_pair(ADD, (char*)$1, tmpvaltype, tmpvalstr);
		list_append(plist, (void *)tmppair);
		mem_free(tmpvalstr);
	}
	| WORD SUB constant {
		debugvf("Pair (WORD-=constant): %s -= %s\n", (char *)$1, tmpvalstr);
		if (!plist)
			plist = list_new();
		tmppair = sqlstmt_new_pair(SUB, (char*)$1, tmpvaltype, tmpvalstr);
		list_append(plist, (void *)tmppair);
		mem_free(tmpvalstr);
	}
	;

filter:
	WORD EQUALS constant {
		debugvf("Filter (WORD==constant): %s == %s\n",
			(char *)$1, tmpvalstr);
		if (!flist)
			flist = list_new();
		tmpfilter = sqlstmt_new_filter(EQUALS, (char*)$1,
					       tmpvaltype, tmpvalstr);
		list_append(flist, (void *)tmpfilter);
		mem_free(tmpvalstr);
	}
	| WORD LESS constant {
		debugvf("Filter (WORD<constant): %s == %s\n",
			(char *)$1, tmpvalstr);
		if (!flist)
			flist = list_new();
		tmpfilter = sqlstmt_new_filter(LESS, (char*)$1,
					       tmpvaltype, tmpvalstr);
		list_append(flist, (void *)tmpfilter);
		mem_free(tmpvalstr);
	}
	| WORD GREATER constant {
		debugvf("Filter (WORD>constant): %s == %s\n",
                        (char *)$1, tmpvalstr);
		if (!flist)
			flist = list_new();
		tmpfilter = sqlstmt_new_filter(GREATER, (char*)$1,
                                               tmpvaltype, tmpvalstr);
		list_append(flist, (void *)tmpfilter);
		mem_free(tmpvalstr);
	}
	| WORD LESSEQ constant {
		debugvf("Filter (WORD<=constant): %s == %s\n",
                        (char *)$1, tmpvalstr);
		if (!flist)
			flist = list_new();
		tmpfilter = sqlstmt_new_filter(LESSEQ, (char*)$1,
                                               tmpvaltype, tmpvalstr);
		list_append(flist, (void *)tmpfilter);
		mem_free(tmpvalstr);
	}
	| WORD GREATEREQ constant {
		debugvf("Filter (WORD>=constant): %s == %s\n",
                        (char *)$1, tmpvalstr);
		if (!flist)
			flist = list_new();
		tmpfilter = sqlstmt_new_filter(GREATEREQ, (char*)$1,
                                               tmpvaltype, tmpvalstr);
		list_append(flist, (void *)tmpfilter);
		mem_free(tmpvalstr);
	}
	| WORD CONTAINS constant {
		debugvf("Filter (WORD contains constant): %s contains %s\n",
			(char *)$1, tmpvalstr);
		if (!flist)
			flist = list_new();
		tmpfilter = sqlstmt_new_filter(CONTAINS, (char*)$1, tmpvaltype, tmpvalstr);
		list_append(flist, (void *)tmpfilter);
		mem_free(tmpvalstr);
	}
	| WORD NOTCONTAINS constant {
		debugvf("Filter (WORD notcontains constant): %s notcontains %s\n",
			(char *)$1, tmpvalstr);
		if (!flist)
			flist = list_new();
		tmpfilter = sqlstmt_new_filter(NOTCONTAINS, (char*)$1, tmpvaltype, tmpvalstr);
		list_append(flist, (void *)tmpfilter);
		mem_free(tmpvalstr);
	}
	;

constant: NUMBER {
		tmpvaltype = INTEGER;
		tmpvalstr = (char *)$1;
	}
	| NUMFLOAT {
		tmpvaltype = REAL;
		tmpvalstr = (char *)$1;
	}
	| tstamp_expression {
		tmpvaltype = TSTAMP;
		tmpvalstr = (char *)$1;
	}
        | QUOTEDSTRING {
	        char *p = (char *)malloc(strlen($1));
	        sscanf($1,"\"%s\"",p);
       	        int i;
	        debugvf("Value varchar: %s\n", $1);
	        i = strlen(p) - 1;	/* will point at \" || \n*/
	        p[i] = '\0';		/* overwrite it */
	  
	        tmpvaltype = VARCHAR;
	        tmpvalstr = strdup(p);
		
	}
	;

orderList:
	WORD {
		debugvf("Order by: %s\n", (char *)$1);
		orderby = $1;
	}
	;

groupList:
	groupcol 
	| groupList COMMA groupcol
	;

groupcol:
	WORD {
		debugvf("Group by col: %s\n", (char *)$1);
		if (!grouplist)
			grouplist = list_new();
		list_append(grouplist, (void *)$1);
	}

createStmt:
	CREATE tabDecl WORD { column = 0; } OPENBRKT varDecls CLOSEBRKT {
		debugvf("Tablename: %s\n", (char *)$3);
		tablename = $3;
	}
	;

tabDecl:
	TABLETK {
		debugvf("tabDec: table\n");
		tabletype = 0;
		primary_column = -1;
	}
	| PERSISTENTTABLETK {
		debugvf("tabDec: persistenttable\n");
		tabletype = 1;
		primary_column = -1;
	}
	;
	
varDecls:
	varDec
	| varDecls COMMA varDec
	;
	
varDec:
	WORD BOOLEAN SQLattrib {
		debugvf("varDec boolean: %s\n", $1);
		
		column++;
		if (!colnames)
			colnames = list_new();
		list_append(colnames, (void *)$1);
		
		if (!coltypes)
			coltypes = list_new();
		list_append(coltypes, (void *)PRIMTYPE_BOOLEAN);
	}
	| WORD INTEGER SQLattrib {
		debugvf("varDec integer: %s\n", $1);
		
		column++;
		if (!colnames)
			colnames = list_new();
		list_append(colnames, (void *)$1);
		
		if (!coltypes)
			coltypes = list_new();
		list_append(coltypes, (void *)PRIMTYPE_INTEGER);
	}
	| WORD REAL SQLattrib {
		debugvf("varDec real: %s\n", $1);
		
		column++;
		if (!colnames)
			colnames = list_new();
		list_append(colnames, (void *)$1);
		
		if (!coltypes)
			coltypes = list_new();
		list_append(coltypes, (void *)PRIMTYPE_REAL);
	}
	| WORD CHARACTER SQLattrib {
		debugvf("varDec character: %s\n", $1);
		
		column++;
		if (!colnames)
			colnames = list_new();
		list_append(colnames, (void *)$1);
		
		if (!coltypes)
			coltypes = list_new();
		list_append(coltypes, (void *)PRIMTYPE_CHARACTER);
	}
	| WORD VARCHAR OPENBRKT NUMBER CLOSEBRKT SQLattrib {
		debugvf("varDec varchar: %s\n", $1);
		
		column++;
		if (!colnames)
			colnames = list_new();
		list_append(colnames, (void *)$1);
		
		if (!coltypes)
			coltypes = list_new();
		list_append(coltypes, (void *)PRIMTYPE_VARCHAR);
		
		mem_free($4);
	}
	| WORD BLOB OPENBRKT NUMBER CLOSEBRKT SQLattrib {
		debugvf("varDec blob: %s\n", $1);
		
		column++;
		if (!colnames)
			colnames = list_new();
		list_append(colnames, (void *)$1);
		
		if (!coltypes)
			coltypes = list_new();
		list_append(coltypes, (void *)PRIMTYPE_BLOB);
	}
	| WORD TINYINT SQLattrib {
		debugvf("varDec tinyint: %s\n", $1);
		
		column++;
		if (!colnames)
			colnames = list_new();
		list_append(colnames, (void *)$1);
		
		if (!coltypes)
			coltypes = list_new();
		list_append(coltypes, (void *)PRIMTYPE_TINYINT);
	}
	| WORD SMALLINT SQLattrib {
		debugvf("varDec smallint: %s\n", $1);
		
		column++;
		if (!colnames)
			colnames = list_new();
		list_append(colnames, (void *)$1);
		
		if (!coltypes)
			coltypes = list_new();
		list_append(coltypes, (void *)PRIMTYPE_SMALLINT);
	}
	| WORD TSTAMP SQLattrib {
		debugvf("varDec timestamp: %s\n", $1);
		
		column++;
		if (!colnames)
			colnames = list_new();
		list_append(colnames, (void *)$1);
		
		if (!coltypes)
			coltypes = list_new();
		list_append(coltypes, (void *)PRIMTYPE_TIMESTAMP);
	}
	;

SQLattrib:
	  /* empty */ { /* do nothing */
	}
	| PRIMARY KEY {
		if (! tabletype) {
			errorf("primary key defined for non-persistent table.\n");
			YYABORT;
		} else if (primary_column != -1) {
			errorf("two or more primary keys declared\n");
			YYABORT;
		} else {
			primary_column = column;
		}
	}
	;

insertStmt:
	INSERT INTO WORD VALUES OPENBRKT valList CLOSEBRKT {
		debugvf("Tablename: %s\n", (char *)$3);
		tablename = $3;
		transform = 0;
	}
	| INSERT INTO WORD VALUES OPENBRKT valList CLOSEBRKT ON DUPLICATETK KEY UPDATE {
		debugvf("Tablename: %s\n", (char *)$3);
		tablename = $3;
		transform = 1;
	} 
	;

updateStmt:
	UPDATE WORD SET pairList WHERE filterList {
		debugvf("Update table %s\n", (char *)$2);
		tablename = $2;
	}
	;
	
valList:
	val
	| valList COMMA val
	;

val:
	SINGLEQUOTE TRUETK SINGLEQUOTE {
		debugvf("Value bool true\n");
		
		if (!colvals)
			colvals = list_new();
		list_append(colvals, str_dupl("1"));
		
		if (!coltypes)
			coltypes = list_new();
		list_append(coltypes, (void *)PRIMTYPE_BOOLEAN);
	}
	| SINGLEQUOTE FALSETK SINGLEQUOTE {
		debugvf("Value bool false\n");
		
		if (!colvals)
			colvals = list_new();
		list_append(colvals, str_dupl("0"));
		
		if (!coltypes)
			coltypes = list_new();
		list_append(coltypes, (void *)PRIMTYPE_BOOLEAN);
	}
	| SINGLEQUOTE NUMBER SINGLEQUOTE {
		debugvf("Value int: %s\n", $2);
		
		if (!colvals)
			colvals = list_new();
		list_append(colvals, (void *)$2);
		
		if (!coltypes)
			coltypes = list_new();
		list_append(coltypes, (void *)PRIMTYPE_INTEGER);
	}
	| SINGLEQUOTE NUMFLOAT SINGLEQUOTE {
		debugvf("Value real: %s\n", $2);
		
		if (!colvals)
			colvals = list_new();
		list_append(colvals, (void *)$2);
		
		if (!coltypes)
			coltypes = list_new();
		list_append(coltypes, (void *)PRIMTYPE_REAL);
	}
	| SINGLEQUOTE TSTAMP SINGLEQUOTE {
		debugvf("Value tstamp: %s\n", $2);
		
		if (!colvals)
			colvals = list_new();
		list_append(colvals, (void *)$2);
		
		if (!coltypes)
			coltypes = list_new();
		list_append(coltypes, (void *)PRIMTYPE_TIMESTAMP);
	}
	| SINGLEQUOTE WORD SINGLEQUOTE {
		debugvf("Value varchar: %s\n", $2);
		
		if (!colvals)
			colvals = list_new();
		list_append(colvals, (void *)$2);
		
		if (!coltypes)
			coltypes = list_new();
		list_append(coltypes, (void *)PRIMTYPE_VARCHAR);
	}
	| QUOTEDSTRING {
		char *p = $1;
		int i;
		debugvf("Value varchar: %s\n", $1);
		i = strlen(p) - 1;	/* will point at \" || \n*/
		p[i] = '\0';		/* overwrite it */

		if (!colvals)
			colvals = list_new();
		list_append(colvals, (void *)str_dupl(p+1));
		mem_free($1);
		
		if (!coltypes)
			coltypes = list_new();
		list_append(coltypes, (void *)PRIMTYPE_VARCHAR);
	}
	| error {
		debugvf("Wrong value.\n");
	}
	;

%%

