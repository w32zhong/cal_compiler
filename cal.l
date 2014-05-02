%{
#include <stdlib.h>  /* for atoi()   */
#include <stdio.h>   /* for printf() */
#include <string.h>  /* for strdup() */
#include <ctype.h>   /* for toupper() */

extern int line_num; /* line number from cal.tab.c */
%}

%%
[ \t]+          {}
\n              { line_num++; return '\n'; }
"+"|"-"|"*"|"/" { return yytext[0]; }
"("|")"|"="     { return yytext[0]; }
[0-9]+          { yylval.tok = strdup(yytext); 
                  return NUM; }
[a-zA-Z_]+      { 
                  char *pp, *p = strdup(yytext);
                  pp = p;
                  while (*p != '\0') {
                  	*p = toupper(*p);
                  	p++;
                  }
                  yylval.tok = pp; 
                  return VAR; }
.               { printf("lexer error at line %d: " 
                  "illegal token `%s'\n", line_num, yytext);
                  return 0; }
%%
