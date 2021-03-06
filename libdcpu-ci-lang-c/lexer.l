%{

/**

	File:           lexer.y

	Project:        DCPU-16 Tools
	Component:      LibDCPU-ci-lang-c

	Authors:        James Rhodes
	                Michael Gerhaeuser

	Description:    Defines lexer for the compiler.

**/
	
#include <lexfix.h>
#include <string>
#include <cstdio>
#include "nodes/NBlock.h"
#include "nodes/NExpression.h"
#include "nodes/NStatement.h"
#include "nodes/NIdentifier.h"
#include "nodes/NInteger.h"
#include "nodes/NType.h"
#include "nodes/NDeclarations.h"
#include "nodes/NFunctionDeclaration.h"
#include "nodes/NStructureDeclaration.h"
#include "nodes/NVariableDeclaration.h"
#include "nodes/Lists.h"
#include "parser.hpp"

unsigned int yyclineno = 1;
int yycolumn = 0;
void count();
void comment_line();
void comment();
extern "C" int yywrap() { return 1; }
char* trim_and_unescape(char* data, int mode);
int check_type();
extern int string_return;

#define HANDLE count()

%}

%x IN_CHAR
%x IN_STRING
%x AT_ASM
%x IN_ASM_BLOCK

%%

	/* Constants */
	
"true"					{ HANDLE; return TRUE; }
"false"					{ HANDLE; return FALSE; }
"NULL"					{ HANDLE; return FALSE; }

	/* Statement keywords */

"return"				{ HANDLE; return RETURN; }
"if"					{ HANDLE; return IF; }
"else"					{ HANDLE; return ELSE; }
"while"					{ HANDLE; return WHILE; }
"for"					{ HANDLE; return FOR; }
"debug"					{ HANDLE; return DEBUG; }
"struct"				{ HANDLE; return STRUCT; }
"sizeof"				{ HANDLE; return SIZEOF; }

	/* Inline assembly */

"__asm"					{ HANDLE; BEGIN(AT_ASM); }
<AT_ASM>\{				{ HANDLE; BEGIN(IN_ASM_BLOCK); string_return = AT_ASM; }
<AT_ASM>\n				{ yyclineno++; }
<AT_ASM>[ \t]+				/* ignore whitespace */;
<AT_ASM>[^\{]				{ HANDLE; return ERROR; }
<IN_ASM_BLOCK>\}			{ HANDLE; BEGIN(INITIAL); string_return = INITIAL; }
<IN_ASM_BLOCK>[^\}]*			{ HANDLE; yylval.string = new std::string(yytext); return ASSEMBLY; }
<IN_ASM_BLOCK>\n			{ yyclineno++; }
<IN_ASM_BLOCK>[ \t]+			/* ignore whitespace */;

	/* Type keywords */

"void"					{ HANDLE; return TYPE_VOID; }
"char"					{ HANDLE; return TYPE_CHAR; }
"byte"					{ HANDLE; return TYPE_BYTE; }
"int"					{ HANDLE; return TYPE_INT; }
"long"					{ HANDLE; return TYPE_LONG; }
"int8_t"				{ HANDLE; return TYPE_INT8_T; }
"int16_t"				{ HANDLE; return TYPE_INT16_T; }
"int32_t"				{ HANDLE; return TYPE_INT32_T; }
"int64_t"				{ HANDLE; return TYPE_INT64_T; }
"uint8_t"				{ HANDLE; return TYPE_UINT8_T; }
"uint16_t"				{ HANDLE; return TYPE_UINT16_T; }
"uint32_t"				{ HANDLE; return TYPE_UINT32_T; }
"uint64_t"				{ HANDLE; return TYPE_UINT64_T; }

	/* String and character analysis */

\'					{ HANDLE; yylval.string = new std::string(); BEGIN(IN_CHAR); }
\"					{ HANDLE; yylval.string = new std::string(); BEGIN(IN_STRING); }
<IN_CHAR>\'				{ HANDLE; BEGIN(string_return); return CHARACTER; }
<IN_STRING>\"				{ HANDLE; BEGIN(string_return); return STRING; }
<IN_STRING,IN_CHAR>\\a			{ HANDLE; *yylval.string += '\a'; }
<IN_STRING,IN_CHAR>\\b			{ HANDLE; *yylval.string += '\b'; }
<IN_STRING,IN_CHAR>\\f			{ HANDLE; *yylval.string += '\f'; }
<IN_STRING,IN_CHAR>\\n			{ HANDLE; *yylval.string += '\n'; }
<IN_STRING,IN_CHAR>\\r			{ HANDLE; *yylval.string += '\r'; }
<IN_STRING,IN_CHAR>\\t			{ HANDLE; *yylval.string += '\t'; }
<IN_STRING,IN_CHAR>\\v			{ HANDLE; *yylval.string += '\v'; }
<IN_STRING,IN_CHAR>\\\'			{ HANDLE; *yylval.string += '\''; }
<IN_STRING,IN_CHAR>\\\"			{ HANDLE; *yylval.string += '\"'; }
<IN_STRING,IN_CHAR>\\\\			{ HANDLE; *yylval.string += '\\'; }
<IN_STRING,IN_CHAR>\\\?			{ HANDLE; *yylval.string += '\?'; }
<IN_STRING,IN_CHAR>\\[0-7]{1,3}		{ HANDLE; *yylval.string += (char)strtoul(yytext + 1, NULL, 8); }
<IN_STRING,IN_CHAR>\\x[a-fA-F0-9]{2}	{ HANDLE; *yylval.string += (char)strtoul(yytext + 2, NULL, 16); }
<IN_STRING,IN_CHAR>\\[0-9]+		{ HANDLE; return ERROR; }
<IN_STRING,IN_CHAR>\\(.|\n)		{ HANDLE; *yylval.string += yytext[1]; }
<IN_STRING>[^\\\n\"]+			{ HANDLE; *yylval.string += yytext; }
<IN_CHAR>[^\\\n\']+			{ HANDLE; *yylval.string += yytext; }

	/* Identifiers, numbers and basic lexical components */

[A-Za-z_][A-Za-z0-9_]*			{ HANDLE; yylval.string = new std::string(yytext); return check_type(); }
0x[0-9A-Fa-f]+				{ HANDLE; yylval.number = strtoul(yytext, NULL, 16); return NUMBER; }
[1-9]+[0-9]*				{ HANDLE; yylval.number = strtoul(yytext, NULL, 10); return NUMBER; }
0[0-7]*					{ HANDLE; yylval.number = strtoul(yytext, NULL, 8); return NUMBER; }
0b[0-1]+				{ HANDLE; yylval.number = strtoul(yytext, NULL, 2); return NUMBER; }
"("					{ HANDLE; return yylval.token = CURVED_OPEN; }
")"					{ HANDLE; return yylval.token = CURVED_CLOSE; }
"{"					{ HANDLE; return yylval.token = BRACE_OPEN; }
"}"					{ HANDLE; return yylval.token = BRACE_CLOSE; }
","					{ HANDLE; return yylval.token = COMMA; }
"*"					{ HANDLE; return yylval.token = STAR; }
";"					{ HANDLE; return yylval.token = SEMICOLON; }
"."					{ HANDLE; return yylval.token = DOT; }

	/* Assignment, equivilance and mathematical operators */

"="					{ HANDLE; return yylval.token = ASSIGN_EQUAL; }
"+="					{ HANDLE; return yylval.token = ASSIGN_ADD; }
"-="					{ HANDLE; return yylval.token = ASSIGN_SUBTRACT; }
"*="					{ HANDLE; return yylval.token = ASSIGN_MULTIPLY; }
"/="					{ HANDLE; return yylval.token = ASSIGN_DIVIDE; }
"=="					{ HANDLE; return yylval.token = COMPARE_EQUAL; }
"!="					{ HANDLE; return yylval.token = COMPARE_NOT_EQUAL; }
"<"					{ HANDLE; return yylval.token = COMPARE_LESS_THAN; }
"<="					{ HANDLE; return yylval.token = COMPARE_LESS_THAN_EQUAL; }
">"					{ HANDLE; return yylval.token = COMPARE_GREATER_THAN; }
">="					{ HANDLE; return yylval.token = COMPARE_GREATER_THAN_EQUAL; }
"!"					{ HANDLE; return yylval.token = NEGATE; }
"++"					{ HANDLE; return yylval.token = INCREMENT; }
"--"					{ HANDLE; return yylval.token = DECREMENT; }
"+"					{ HANDLE; return yylval.token = ADD; }
"-"					{ HANDLE; return yylval.token = SUBTRACT; }
"/"					{ HANDLE; return yylval.token = SLASH; }
"%"					{ HANDLE; return yylval.token = PERCENT; }
"&&"					{ HANDLE; return yylval.token = BOOLEAN_AND; }
"||"					{ HANDLE; return yylval.token = BOOLEAN_OR; }
"&"					{ HANDLE; return yylval.token = BINARY_AND; }
"|"					{ HANDLE; return yylval.token = BINARY_OR; }
"^"					{ HANDLE; return yylval.token = BINARY_XOR; }
"<<"					{ HANDLE; return yylval.token = BINARY_LEFT_SHIFT; }
">>"					{ HANDLE; return yylval.token = BINARY_RIGHT_SHIFT; }
"~"					{ HANDLE; return yylval.token = BITWISE_NEGATE; }
"!"					{ HANDLE; return yylval.token = NEGATE; }

	/* Comments and whitespace */

\n					{ yyclineno++; }
"//"					{ comment_line(); }
"/*"					{ comment(); }
[ \t]+					/* ignore whitespace */;

%%

int string_return = INITIAL;

void comment()
{
	char c, c1;

loop:
	while ((c = yyinput()) != '*' && c != 0) ;

	if ((c1 = yyinput()) != '/' && c != 0)
		goto loop;
}

void comment_line()
{
	char c;

	while ((c = yyinput()) != '\n' && c != 0) ;
}

void count()
{
	int i;

	for (i = 0; yytext[i] != '\0'; i++)
		if (yytext[i] == '\n')
			yycolumn = 0;
		else if (yytext[i] == '\t')
			yycolumn += 8 - (yycolumn % 8);
		else
			yycolumn++;

	ECHO;
}

int check_type()
{
	// Basically we need to check to see whether our data
	// matches a type name, and return a type token if it
	// does.
	std::string data = yytext;
	if (data == "void")		return TYPE_VOID;
	else if (data == "char")	return TYPE_CHAR;
	else if (data == "byte")	return TYPE_BYTE;
	else if (data == "int")		return TYPE_INT;
	else if (data == "long")	return TYPE_LONG;
	else if (data == "int8_t")	return TYPE_INT8_T;
	else if (data == "int16_t")	return TYPE_INT16_T;
	else if (data == "int32_t")	return TYPE_INT32_T;
	else if (data == "int64_t")	return TYPE_INT64_T;
	else if (data == "uint8_t")	return TYPE_UINT8_T;
	else if (data == "uint16_t")	return TYPE_UINT16_T;
	else if (data == "uint32_t")	return TYPE_UINT32_T;
	else if (data == "uint64_t")	return TYPE_UINT64_T;

	// TODO: When we support typedef's later on, we also
	// need to check here for those as well.

	return IDENTIFIER;
}
