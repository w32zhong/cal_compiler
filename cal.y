%{
#include <stdio.h>  /* for printf() */
#include <stdlib.h> /* for free() */
#include <string.h> /* for strdup() */
#include "list.h"   /* for list */

#define ANSI_COLOR_RST     "\e[0m"
#define ANSI_COLOR_RED     "\x1b[31m"
#define BOLDRED     "\033[1m\033[31m"      /* Bold Red */
#define BOLDGREEN   "\033[1m\033[32m"      /* Bold Green */
#define BOLDYELLOW  "\033[1m\033[33m"      /* Bold Yellow */
#define BOLDBLUE    "\033[1m\033[34m"      /* Bold Blue */
#define BOLDMAGENTA "\033[1m\033[35m"      /* Bold Magenta */
#define BOLDCYAN    "\033[1m\033[36m"      /* Bold Cyan */

extern int line_num;

typedef struct VAR_T {
	struct list_node ln;
	char *name;
	int   ssa_sub;
	int   ssa_use;
} var_t;

struct code_t {
	struct list_node ln;
	var_t  *opr0, *opr1, *opr2;
	char    op;
	int     line_num;
	int     dead_flag;
};

struct code_t *code_gen(var_t*, var_t*, char, var_t*);
var_t         *var_map(char *);
void           yyerror(const char *);
void           code_print();
void           var_print();
char          *tmp_name();
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
program :
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

char is_number(char c)
{
	return (48 <= c && c <= 57);
}

char *tmp_name()
{
	static int tmp_cnt = 0;
	static char tmp_nm[64];

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

void _print_var(FILE *f, var_t *v)
{
	fprintf(f, "%s", v->name);
	if (v->ssa_sub != 0)
		fprintf(f, "_%d", v->ssa_sub);
}

static
LIST_IT_CALLBK(print_var)
{
	LIST_OBJ(var_t, p, ln);
	
	_print_var(stdout, p);

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

void _print_code(FILE *f, struct code_t *p)
{
	if (p->op == '+' || (p->op == '-' && p->opr1 != NULL) ||
	    p->op == '*' || p->op == '/') {
		fprintf(f, "S%d:\t", p->line_num);
		_print_var(f, p->opr0);
		fprintf(f, " = ");
		_print_var(f, p->opr1);
		fprintf(f, " %c ", p->op);
		_print_var(f, p->opr2);
	} else if (p->op == '-') {
		fprintf(f, "S%d:\t", p->line_num);
		_print_var(f, p->opr0);
		fprintf(f, " = -");
		_print_var(f, p->opr2);
	} else if (p->op == '=') {
		fprintf(f, "S%d:\t", p->line_num);
		_print_var(f, p->opr0);
		fprintf(f, " = ");
		_print_var(f, p->opr2);
	}

	fprintf(f, ";\n");
}

static
LIST_IT_CALLBK(print_code)
{
	LIST_OBJ(struct code_t, p, ln);
	_print_code(stdout, p);
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

var_t *var_map(char *name)
{
	struct pa_id_var pa = {name, NULL};
	list_foreach(&var_list, &id_var, &pa);

	if (pa.var == NULL) {
		pa.var = malloc(sizeof(var_t));
		LIST_NODE_CONS(pa.var->ln);
		pa.var->name = strdup(name);
		pa.var->ssa_sub = 0;
		pa.var->ssa_use = 0;

		list_insert_one_at_tail(&pa.var->ln, &var_list, NULL, NULL);
	}

	return pa.var;
}

struct code_t *code_gen(var_t* opr0, 
		var_t* opr1, char op, var_t* opr2)
{
	struct code_t *code = malloc(sizeof(struct code_t));
	static int line_num = 0;
	LIST_NODE_CONS(code->ln);
	code->opr0 = opr0;
	code->op = op;
	code->opr1 = opr1;
	code->opr2 = opr2;
	code->line_num = line_num ++;
	code->dead_flag = 0;

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

static
LIST_IT_CALLBK(print_c_def)
{
	LIST_OBJ(var_t, p, ln);
	P_CAST(cf, FILE, pa_extra);
	char *str = p->name;

	if (is_number(str[0]))
		LIST_GO_OVER;
	else if (is_number(str[strlen(str) - 1]))
		fprintf(cf, "\tint %s;\n", p->name);
	else
		fprintf(cf, "\tint %s = 0;\n", p->name);

	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(print_c_code)
{
	LIST_OBJ(struct code_t, p, ln);
	P_CAST(cf, FILE, pa_extra);
	_print_code(cf, p);
	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(print_c_print)
{
	LIST_OBJ(var_t, p, ln);
	P_CAST(cf, FILE, pa_extra);
	char *str = p->name;

	if (is_number(str[0]))
		LIST_GO_OVER;
	else if (is_number(str[strlen(str) - 1]))
		LIST_GO_OVER;
	else
		fprintf(cf, "\tprintf(\"%s = %%d\\n\", %s);\n", 
				p->name, p->name);

	LIST_GO_OVER;
}

char printed_flag;

static
LIST_IT_CALLBK(print_flow_dep)
{
	LIST_OBJ(struct code_t, p, ln);
	P_CAST(q, struct code_t, pa_extra);
	
	if (p == q) {
		return LIST_RET_BREAK;
	} else if (p->opr0 == q->opr1 || p->opr0 == q->opr2) {
		printf("S%d ", p->line_num);
		printed_flag = 0;
	}
 
	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(print_anti_dep)
{
	LIST_OBJ(struct code_t, p, ln);
	P_CAST(q, struct code_t, pa_extra);
	
	if (p == q) {
		return LIST_RET_BREAK;
	} else if (p->opr1 == q->opr0 || p->opr2 == q->opr0) {
		printf("S%d ", p->line_num);
		printed_flag = 0;
	}
 
	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(print_write_dep)
{
	LIST_OBJ(struct code_t, p, ln);
	P_CAST(q, struct code_t, pa_extra);
	
	if (p == q) {
		return LIST_RET_BREAK;
	} else if (p->opr0 == q->opr0 || p->opr0 == q->opr0) {
		printf("S%d ", p->line_num);
		printed_flag = 0;
	}
 
	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(print_dep)
{
	LIST_OBJ(struct code_t, p, ln);
	
	printf("S%d:\n", p->line_num);

	printf("flow dependency: ");
	printed_flag = 1;
	list_foreach(&code_list, &print_flow_dep, p);
	if (printed_flag)
		printf("None");
	printf("\n");

	printf("anti-dependency: ");
	printed_flag = 1;
	list_foreach(&code_list, &print_anti_dep, p);
	if (printed_flag)
		printf("None");
	printf("\n");

	printf("write-dependency: ");
	printed_flag = 1;
	list_foreach(&code_list, &print_write_dep, p);
	if (printed_flag)
		printf("None");
	printf("\n");

	LIST_GO_OVER;
}

struct live_arg {
	int start, end, life;
	var_t *var;
	struct list_node *end_node;
};

static
LIST_IT_CALLBK(live_calc)
{
	LIST_OBJ(struct code_t, p, ln);
	P_CAST(la, struct live_arg, pa_extra);

	if (pa_now->now == pa_head->now) {
		la->start = la->end = p->line_num;
		la->life = 0; 
	}

	if (p->line_num > la->start) {
		if (p->opr1 == la->var || p->opr2 == la->var) {
			la->end = p->line_num;
			la->life = p->line_num - la->start;
		} 

		if (p->opr0 == la->var) {
			return LIST_RET_BREAK;
		}
	}

	if (pa_now->now == la->end_node)
		return LIST_RET_BREAK;
	else
		return LIST_RET_CONTINUE;
}

#define CONST_LONG_LIVENESS 1000

void get_liveness(var_t *var, struct list_it *sub_list,
		struct live_arg *la)
{
	struct code_t *code = MEMBER_2_STRUCT(sub_list->now, 
			struct code_t, ln);
	char *str;

	if (var == NULL) {
no_life:
		la->start = la->end = code->line_num;
		la->life = 0;
		return;

	} else {
		str = var->name;
		if (is_number(str[0])) {
			goto no_life;
		} else {
			la->var = var;
			list_foreach(sub_list, &live_calc, la);
		}

		_print_var(stdout, var);
		printf(" liveness: %d to %d (%d).\n",
				la->start, la->end, la->life);
	}
}

int heuristic_live(struct list_it *sub_list, struct list_it *pa_head)
{
	struct list_it *pa_now = sub_list;
	struct live_arg la = {0, 0, 0, NULL, pa_head->last};
	int res = 0;
	LIST_OBJ(struct code_t, p, ln);

	get_liveness(p->opr0, sub_list, &la);
	res += la.life;
	
	get_liveness(p->opr1, sub_list, &la);
	res += la.life;
	
	get_liveness(p->opr2, sub_list, &la);
	res += la.life;
	
	return res;
}

#define ELI_EVAL(_stmt) \
		printf("these two code may be optimized:\n"); \
		_print_code(stdout, s1); \
		_print_code(stdout, s2); \
 \
		printf("liveness in S%d: \n", s1->line_num); \
		live1 = heuristic_live(sub_list, pa_head); \
		printf("if no change: sum(liveness) = %d\n", live1); \
 \
		_stmt; \
		printf("if S%d is changed to: \n", s2->line_num); \
		_print_code(stdout, s2); \
 \
		printf("liveness in S%d: \n", s1->line_num); \
		live2 = heuristic_live(sub_list, pa_head); \
		printf("if changed: sum(liveness) = %d\n", live2)

int elimination_cse(struct code_t *s1, struct code_t *s2,
		struct list_it *sub_list, struct list_it *pa_head)
{
	struct code_t old_s2 = *s2;
	int live1, live2 = -1;

	if (s1->opr1 != NULL) {
		if (s1->opr1 == s2->opr1 &&
				s1->opr2 == s2->opr2 && s1->op == s2->op) {

			ELI_EVAL(
					s2->opr1 = NULL;
					s2->opr2 = s1->opr0;
					s2->op = '=';
					);
		}
	} else {
	
		if (s2->opr1 != NULL && s1->op != '-') {
			if (s1->opr2 == s2->opr1) {
				ELI_EVAL(s2->opr1 = s1->opr0);
			} else if (s1->opr2 == s2->opr2) {
				ELI_EVAL(s2->opr2 = s1->opr0);
			}
		} else {
			if (s1->op == '=') {
				if (s2->opr2 == s1->opr2) {
					ELI_EVAL(s2->opr2 = s1->opr0);
				}
			} else if (s1->op == '-' && s2->op == '-') {
				if (s2->opr2 == s1->opr2) {
					ELI_EVAL(s2->opr2 = s1->opr0);
				}
			}
		}
	}

	if (live2 != -1) {
		if (live1 - live2 > 0) {
			printf(BOLDGREEN
					"do Common Sub-expression Elimination.\n" 
					ANSI_COLOR_RST);
			return 0;
		} else {
			printf(BOLDBLUE 
					"better do nothing.\n" 
					ANSI_COLOR_RST);
			*s2 = old_s2;
		}
	}

	return 1;
}

int elimination_ce(struct code_t *s1, struct code_t *s2,
		struct list_it *sub_list, struct list_it *pa_head)
{
	struct code_t old_s2 = *s2;
	int live1, live2 = -1;

	if (s1->opr1 != NULL) {
		if (s2->opr1 == NULL && s2->op == '=') { 
			if (s1->opr0 == s2->opr2) {
				ELI_EVAL(
						s2->opr1 = s1->opr1;
						s2->op = s1->op;
						s2->opr2 = s1->opr2
						);
			}
		}
	} else {
		if (s2->opr1 != NULL) {
			if (s2->opr1 == s1->opr0) {
				ELI_EVAL(s2->opr1 = s1->opr2);
			}
			if (s2->opr2 == s1->opr0) {
				ELI_EVAL(s2->opr2 = s1->opr2);
			}
		} else {
			if (s2->opr2 == s1->opr0) {
				if (s1->op == '=') {
					ELI_EVAL(s2->opr2 = s1->opr2);
				} else if (s1->op == '-' && s2->op == '=') {
					ELI_EVAL(
							s2->op = '-';
							s2->opr2 = s1->opr2
							);
				}
			}
		}
	}

	if (live2 != -1) {
		if (live1 - live2 >= 0) {
			printf(BOLDGREEN 
					"do Copy Elimination.\n" 
					ANSI_COLOR_RST);
			return 0;
		} else {
			printf(BOLDBLUE 
					"better do nothing.\n" 
					ANSI_COLOR_RST);
			*s2 = old_s2;
		}
	}

	return 1;
}

struct elim_arg {
	struct list_node *end_node;
	struct code_t    *s1;
	struct list_it   *sub_list;
	int               fixed_point;
};

static
LIST_IT_CALLBK(eli_s2)
{
	LIST_OBJ(struct code_t, p, ln);
	P_CAST(ea, struct elim_arg, pa_extra);
	struct code_t *s1 = ea->s1, *s2 = p;
	
	if (s1 != s2) {
		ea->fixed_point &= 
			elimination_cse(s1, s2, ea->sub_list, pa_head);

		ea->fixed_point &= 
			elimination_ce(s1, s2, ea->sub_list, pa_head);
	}

	if (pa_now->now == ea->end_node)
		return LIST_RET_BREAK;
	else
		return LIST_RET_CONTINUE;
}

static
LIST_IT_CALLBK(eli_s1)
{
	LIST_OBJ(struct code_t, p, ln);
	P_CAST(ea, struct elim_arg, pa_extra);
	struct list_it sub_list = list_get_it(pa_now->now);
	ea->end_node = pa_head->last;
	ea->s1       = p;
	ea->sub_list = &sub_list;

	list_foreach(&sub_list, &eli_s2, ea);

	LIST_GO_OVER;
}

static void code_optimization()
{
	struct elim_arg ea;
	ea.fixed_point = 0;
	int cnt = 0;
	while (!ea.fixed_point) {
		ea.fixed_point = 1;
		list_foreach(&code_list, &eli_s1, &ea);
		printf("CSE/CE %dth iteration done.\n", ++cnt);
	}
}

struct _2ssa_arg {
	var_t *dead;
	var_t *new;
	struct code_t *s1;
	struct list_node *end_node;
};

static
LIST_IT_CALLBK(_2ssa_s2)
{
	LIST_OBJ(struct code_t, s2, ln);
	P_CAST(_2sa, struct _2ssa_arg, pa_extra);
	
	if (_2sa->s1 != s2) {
		if (s2->opr0 == _2sa->dead)
			s2->opr0 = _2sa->new;
		if (s2->opr1 == _2sa->dead)
			s2->opr1 = _2sa->new;
		if (s2->opr2 == _2sa->dead)
			s2->opr2 = _2sa->new;
	}

	if (pa_now->now == _2sa->end_node)
		return LIST_RET_BREAK;
	else
		return LIST_RET_CONTINUE;
}

static
LIST_IT_CALLBK(_2ssa_s1)
{
	LIST_OBJ(struct code_t, p, ln);
	struct list_it sub_list = list_get_it(pa_now->now);
	struct _2ssa_arg _2sa;

	_2sa.new = malloc(sizeof(var_t));
	LIST_NODE_CONS(_2sa.new->ln);
	_2sa.new->name = strdup(p->opr0->name);
	_2sa.new->ssa_sub = p->opr0->ssa_sub + 1;
	_2sa.new->ssa_use = 1;
	list_insert_one_at_tail(&_2sa.new->ln, &var_list, NULL, NULL);

	_2sa.dead = p->opr0;
	p->opr0 = _2sa.new;

	_2sa.s1 = p;
	_2sa.end_node = pa_head->last;
	
	if (!_2sa.dead->ssa_use) {
		/* printf("rm ");
		_print_var(stdout, _2sa.dead);
		printf("\n");
		*/

		list_detach_one(&_2sa.dead->ln, &var_list, NULL, NULL);
		free(_2sa.dead->name);
		free(_2sa.dead);
	}

	if (p->opr1 != NULL) 
		p->opr1->ssa_use = 1;
	if (p->opr2 != NULL) 
		p->opr2->ssa_use = 1;

	list_foreach(&sub_list, &_2ssa_s2, &_2sa);

	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(_add_psedu_print_code)
{
	LIST_OBJ(var_t, p, ln);
	char *str = p->name;
	var_t *v;
	
	if (p != NULL && !is_number(str[0]) &&
			!is_number(str[strlen(str) - 1])) {
		v = var_map(tmp_name());
		code_gen(v , NULL, '-', p);
	}

	LIST_GO_OVER;
}

void add_psedu_print_code()
{
	list_foreach(&var_list, &_add_psedu_print_code, NULL);
}

static
LIST_IT_CALLBK(_dead_flag)
{
	BOOL res;
	LIST_OBJ(struct code_t, p, ln);
	struct list_it sub_list = list_get_it(pa_now->now);
	struct live_arg la = {0, 0, 0, NULL, pa_head->last};

	printf("destination operator, ");
	get_liveness(p->opr0, &sub_list, &la);

	if (la.life == 0)
		p->dead_flag = 1;
	
	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(_dead_eli)
{
	BOOL res;
	LIST_OBJ(struct code_t, p, ln);

	if (p->dead_flag) {
		res = list_detach_one(pa_now->now, 
				pa_head, pa_now, pa_fwd);

		printf("rm code:\n");
		_print_code(stdout, p);
		free(p);
		return res;
	}
	
	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(_code_renumber)
{
	BOOL res;
	LIST_OBJ(struct code_t, p, ln);
	P_CAST(num, int, pa_extra);

	p->line_num = *num;
	(*num) ++;

	LIST_GO_OVER;
}

static void code_dead_elimination()
{
	int num = 0;
	list_foreach(&code_list, &_dead_flag, NULL);
	list_foreach(&code_list, &_dead_eli, NULL);
	printf("renumber code...\n");
	list_foreach(&code_list, &_code_renumber, &num);
}

#include "pseudo_test.c"
#define CAL_DEBUG 0

int main() 
{
	FILE *cf;

	if (CAL_DEBUG) 
		pseudo_test_ce_simple();
	else
		yyparse();
	
	/*
	printf("variables:\n"); 
	var_print();
	*/

	printf("three-address code:\n"); 
	add_psedu_print_code();
	printf(BOLDBLUE);
	code_print(); 
	printf(ANSI_COLOR_RST);

	if (0) {
		cf = fopen("output.c", "w");
		if (cf) {
			printf("generate C file...\n");
		} else {
			printf("cannot open file for writing.\n");
			return 0;
		}

		fprintf(cf, "#include <stdio.h> \n");
		fprintf(cf, "int main() \n{ \n");
		list_foreach(&var_list, &print_c_def, cf);
		list_foreach(&code_list, &print_c_code, cf);
		list_foreach(&var_list, &print_c_print, cf);
		fprintf(cf, "\treturn 0; \n} \n");
		fclose(cf);

		printf("dependency: \n");
		list_foreach(&code_list, &print_dep, NULL);
	}
	
	printf("transforming to SSA...\n");
	list_foreach(&code_list, &_2ssa_s1, NULL);
	
	printf("SSA form:\n"); 
	printf(BOLDRED);
	code_print(); 
	printf(ANSI_COLOR_RST);

	printf("doing code optimization...\n"); 
	code_optimization();

	printf("after code optimization:\n"); 
	printf(BOLDGREEN);
	code_print(); 
	printf(ANSI_COLOR_RST);
	
	printf("doing dead code elimination...\n"); 
	code_dead_elimination();
	
	printf("after dead code elimination...\n"); 
	printf(BOLDGREEN);
	code_print(); 
	printf(ANSI_COLOR_RST);

	list_foreach(&var_list, &release_var, NULL);
	list_foreach(&code_list, &release_code, NULL);
	return 0;
}
