%{
#include <stdio.h>  /* for printf() */
#include <stdlib.h> /* for free() */
#include <string.h> /* for strdup() */
#include "list.h"   /* for list */

extern int line_num;

struct var_t {
	struct list_node ln;
	int   val;
	char *name;
};

struct var_t *var_map(char *);
void yyerror(const char *);

char *tmp_name();
%}

%union {
	struct {
		char  *_3addr_name;
		union {
		char  *s;
		int    d;
		} u;
	} a;
};

%error-verbose
%token <a> VAR 
%token <a> NUM
%type  <a> expr factor term assign
%right '=' 
%left '+' '-' 
%left '*' '/' 
%nonassoc '(' ')'
%start program

%%
program : 
        | stmt program;

stmt : expr '\n' { printf("= %d\n", $1.u.d); }
     | '\n' {};

expr   : expr '+' factor 
       { 
         $$.u.d = $1.u.d + $3.u.d; 
       
         $$._3addr_name = strdup(tmp_name());
         printf("%s = %s + %s\n", $$._3addr_name, 
                $1._3addr_name, $3._3addr_name);
       }
       | expr '-' factor 
       { 
         $$.u.d = $1.u.d - $3.u.d; 
       
         $$._3addr_name = strdup(tmp_name());
         printf("%s = %s - %s\n", $$._3addr_name, 
                $1._3addr_name, $3._3addr_name);
       }
       | assign 
       { 
         $$.u.d = $1.u.d; 
         $$._3addr_name = $1._3addr_name;
       }
       | factor 
       { 
         $$.u.d = $1.u.d; 
         $$._3addr_name = $1._3addr_name;
       };

factor : factor '*' term 
       { 
         $$.u.d = $1.u.d * $3.u.d; 
       
         $$._3addr_name = strdup(tmp_name());
         printf("%s = %s * %s\n", $$._3addr_name, 
                $1._3addr_name, $3._3addr_name);
       }
       | factor '/' term 
       { 
         $$.u.d = $1.u.d / $3.u.d; 
       
         $$._3addr_name = strdup(tmp_name());
         printf("%s = %s / %s\n", $$._3addr_name, 
                $1._3addr_name, $3._3addr_name);
       }
       | term
       { 
         $$.u.d = $1.u.d; 
         $$._3addr_name = $1._3addr_name;
       };

term   : NUM 
       { 
         $$.u.d = $1.u.d; 
         $$._3addr_name = $1._3addr_name;
       }
       | '-' factor 
       { 
         $$.u.d = - $2.u.d; 
       
         $$._3addr_name = strdup(tmp_name());
         printf("%s = - %s\n", $$._3addr_name, $2._3addr_name);
       }
       | VAR
       { char err_str[32]; 
         struct var_t *p = var_map($1.u.s);
         $$.u.d = p->val; 
         free($1.u.s);
       }
       | '(' expr ')' 
       { 
         $$.u.d = $2.u.d; 
         $$._3addr_name = $2._3addr_name;
       };

assign : VAR '=' expr  
       { $$.u.d = $3.u.d; 
         struct var_t *p = var_map($1.u.s);
         p->val = $3.u.d;
         /* printf("assign %d to %s\n", 
                 $3.u.d, $1.u.s); */
         free($1.u.s);

         $$._3addr_name = strdup($1._3addr_name);
         printf("%s = %s\n", $$._3addr_name, $3._3addr_name);
       };
%%

int line_num = 1;
struct list_it var_list = {NULL, NULL};

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
	char         *name;
	struct var_t *var;
};

static
LIST_IT_CALLBK(print_var)
{
	LIST_OBJ(struct var_t, p, ln);
	printf("%s=%d", p->name, p->val);
	
	if (pa_now->now == pa_head->last)
		printf(".\n");
	else
		printf(", ");

	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(id_var)
{
	LIST_OBJ(struct var_t, p, ln);
	P_CAST(pa, struct pa_id_var, pa_extra);
	
	if (strcmp(p->name, pa->name) == 0) {
		pa->var = p;
		return LIST_RET_BREAK;
	}

	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(release_var)
{
	BOOL res;
	LIST_OBJ(struct var_t, p, ln);
	res = list_detach_one(pa_now->now, 
			pa_head, pa_now, pa_fwd);

	free(p->name);
	free(p);
	
	return res;
}

struct var_t *var_map(char *name)
{
	struct pa_id_var pa = {name, NULL};
	list_foreach(&var_list, &id_var, &pa);

	if (pa.var == NULL) {
		pa.var = malloc(sizeof(struct var_t));
		LIST_NODE_CONS(pa.var->ln);
		pa.var->val = 0;
		pa.var->name = strdup(name);

		list_insert_one_at_tail(&pa.var->ln, &var_list, NULL, NULL);
	}

	return pa.var;
}

int main() 
{
	yyparse();

	list_foreach(&var_list, &release_var, NULL);
	return 0;
}
