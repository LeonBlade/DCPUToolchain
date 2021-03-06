%{

/**

	File:           lexer.y

	Project:        DCPU-16 Tools
	Component:      LibDCPU-vm-dbg

	Authors:        James Rhodes

	Description:    Defines lexer for the debugger's command-line input.

**/

#include <lexfix.h>
#include <bstrlib.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "parser.h"

char* dbg_trim_and_unescape(char* data, int mode);

%}

%option case-insensitive
%option interactive
%option yylineno
%option noyywrap
%option reentrant
%option bison-bridge
%option prefix="dbg_yy"


%%

	/* Debugger command identifiers */

"load"						return ID_LOAD;
"breakpoint"					return ID_BREAKPOINT;
"break"						return ID_BREAKPOINT;
"run"						return ID_RUN;
"continue"					return ID_CONTINUE;
"stop"						return ID_STOP;
"quit"						return ID_QUIT;
"add"						return ID_ADD;
"delete"					return ID_DELETE;
"attach"					return ID_ATTACH;
"inspect"					return ID_INSPECT;
"hardware"					return ID_HARDWARE;
"cpu"						return ID_CPU;
"detach"					return ID_DETACH;
"list"						return ID_LIST;
"memory"					return ID_MEMORY;
"help"						return ID_HELP;
\?							return ID_HELP;

	/* General stuff */

0x[0-9A-Fa-f]+					yylval->number = strtoul(yytext, NULL, 16); return ADDRESS;
[0-9]+						yylval->number = strtoul(yytext, NULL, 10); return ADDRESS;
[\.\/A-Za-z0-9-]+				yylval->string = bfromcstr(strdup(yytext)); return PATH;
[A-Za-z_-]+[A-Za-z0-9_-]*			yylval->string = bfromcstr(strdup(yytext)); return PARAM;
L?'(\\.|[^\\'])+'				yylval->string = bfromcstr(dbg_trim_and_unescape(strdup(yytext), 1)); return CHARACTER;
L?\"(\\.|[^\\"])*\"				yylval->string = bfromcstr(dbg_trim_and_unescape(strdup(yytext), 0)); return STRING;
\:						return COLON;

[ \t]+						/* ignore whitespace */;

%%

char* dbg_trim_and_unescape(char* data, int mode)
{
	unsigned int i = 0, a = 0;
	char* result = malloc(strlen(data) - 1);
	memset(result, '\0', strlen(data) - 1);
	for (i = 1; i < strlen(data) - 1; i++)
	{
		if (data[i] == '\\' && data[i+1] == '"' && mode == 0)
		{
			result[a] = '"';
			i++; // skip '"'
			a++; // increment position
		}
		else if (data[i] == '\\' && data[i+1] == '\'' && mode == 1)
		{
			result[a] = '\'';
			i++; // skip '"'
			a++; // increment position
		}
		else
		{
			result[a] = data[i];
			a++; // increment position
		}
	}
	free(data);
	return result;
}
