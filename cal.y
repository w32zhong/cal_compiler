%{
#include <stdio.h>  /* for printf() */
#include <stdlib.h> /* for free() */
#include <string.h> /* for strdup() */
#include "list.h"   /* for list */

extern int line_num;

typedef struct VAR_T {
	struct list_node ln;
	char *name;
} var_t;

struct code_t {
	struct list_node ln;
	var_t  *opr0, *opr1, *opr2;
	char    op;
};

struct code_t *code_gen(var_t*, var_t*, char, var_t*);
var_t *var_map(char *);
void yyerror(const char *);
void code_print();
void var_print();
char *tmp_name();
%}

%union {
	char  *tok;
	struct VAR_T *v;
};

%error-verbose
%token <tok> VAR NUM
%type  <v> expr factor term assign
%right '=' 
%left '+' '-' 
%left '*' '/' 
%nonassoc '(' ')'
%start program

%%
program : { code_print(); printf("DEBUG: \n"); var_print(); }
        | stmt program ;

stmt : expr '\n' {  }
     | '\n' { };

expr   : expr '+' factor 
       { 
         var_t *v = var_map(tmp_name());
         $$ = v;
         code_gen(v , $1, '+', $3);
       }
       | expr '-' factor 
       { 
         var_t *v = var_map(tmp_name());
         $$ = v;
         code_gen(v , $1, '-', $3);
       }
       | assign 
       { 
         $$ = $1;
       }
       | factor 
       { 
         $$ = $1;
       };

factor : factor '*' term 
       { 
         var_t *v = var_map(tmp_name());
         $$ = v;
         code_gen(v , $1, '*', $3);
       }
       | factor '/' term 
       { 
         var_t *v = var_map(tmp_name());
         $$ = v;
         code_gen(v , $1, '/', $3);
       }
       | term
       { 
         $$ = $1;
       };

term   : NUM 
       { 
         var_t *v = var_map($1); 
         $$ = v;
         free($1);
       }
       | '-' factor 
       { 
         var_t *v = var_map(tmp_name());
         $$ = v;
         code_gen(v , NULL, '-', $2);
       }
       | VAR
       { 
         var_t *v = var_map($1); 
         $$ = v;
         free($1);
       }
       | '(' expr ')' 
       { 
         $$ = $2;
       };

assign : VAR '=' expr  
       {  
         var_t *v = var_map($1);
         $$ = v;
         code_gen(v , NULL, '=', $3);
       };
%%

int line_num = 1;
struct list_it var_list = {NULL, NULL};
struct list_it code_list = {NULL, NULL};

int tmp_cnt = 0;
static char tmp_nm[64];

char *tmp_name()
{
	sprintf(tmp_nm, "temp%d", tmp_cnt++);
	return tmp_nm;
}

void yyerror(const char *ps) 
{ 
	printf("[yyerror @ %d] %s\n", line_num, ps);
}

struct pa_id_var {
	char       *name;
	var_t      *var;
};

static
LIST_IT_CALLBK(print_var)
{
	LIST_OBJ(var_t, p, ln);
	printf("%s", p->name);
	
	if (pa_now->now == pa_head->last)
		printf(".\n");
	else
		printf(", ");

	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(id_var)
{
	LIST_OBJ(var_t, p, ln);
	P_CAST(pa, struct pa_id_var, pa_extra);
	
	if (strcmp(p->name, pa->name) == 0) {
		pa->var = p;
		return LIST_RET_BREAK;
	}

	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(print_code)
{
	LIST_OBJ(struct code_t, p, ln);
	if (p->op == '+' || (p->op == '-' && p->opr1 != NULL) ||
	    p->op == '*' || p->op == '/')
		printf("%s = %s %c %s\n", p->opr0->name, 
			p->opr1->name, p->op, p->opr2->name);
	else if (p->op == '-')
		printf("%s = %c %s\n", p->opr0->name, 
			p->op, p->opr2->name);
	else if (p->op == '=')
		printf("%s %c %s\n", p->opr0->name, 
			p->op, p->opr2->name);

	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(release_var)
{
	BOOL res;
	LIST_OBJ(var_t, p, ln);
	res = list_detach_one(pa_now->now, 
			pa_head, pa_now, pa_fwd);

	free(p->name);
	free(p);

	return res;
}

static
LIST_IT_CALLBK(release_code)
{
	BOOL res;
	LIST_OBJ(struct code_t, p, ln);
	res = list_detach_one(pa_now->now, 
			pa_head, pa_now, pa_fwd);

	free(p);
	
	return res;
}

char is_number(char c)
{
	return (48 <= c && c <= 57);
}

var_t *var_map(char *name)
{
	struct pa_id_var pa = {name, NULL};
	list_foreach(&var_list, &id_var, &pa);

	if (pa.var == NULL) {
		pa.var = malloc(sizeof(var_t));
		LIST_NODE_CONS(pa.var->ln);
		pa.var->name = strdup(name);

		list_insert_one_at_tail(&pa.var->ln, &var_list, NULL, NULL);
	}

	return pa.var;
}

struct code_t *code_gen(var_t* opr0, 
		var_t* opr1, char op, var_t* opr2)
{
	struct code_t *code = malloc(sizeof(struct code_t));
	LIST_NODE_CONS(code->ln);
	code->opr0 = opr0;
	code->op = op;
	code->opr1 = opr1;
	code->opr2 = opr2;

	list_insert_one_at_tail(&code->ln, &code_list, NULL, NULL);
	return code;
}

void var_print()
{
	list_foreach(&var_list, &print_var, NULL);
}

void code_print()
{
	list_foreach(&code_list, &print_code, NULL);
}

int main() 
{
	yyparse();

	list_foreach(&var_list, &release_var, NULL);
	list_foreach(&code_list, &release_code, NULL);
	printf("Bye!\n");
	return 0;
}
