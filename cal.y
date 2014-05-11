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

	int   live_start;
	int   live_end;
	int   color;
	char *mem_ref;
} var_t;

struct code_t {
	struct list_node ln;
	var_t  *opr0, *opr1, *opr2;
	char    op;
	int     line_num;
	int     dead_flag;

	struct list_it ddg_in;
	struct list_it ddg_out;
	int            ddg_weight;
	int            ddg_in_num;
	
	struct list_node ln_ready;
	struct list_node ln_active;
	int      start_cycle;
};

struct ddg_li_t {
	struct list_node ln;
	struct code_t *code;
};

typedef struct RIG_NODE_T {
	struct list_node ln;
	var_t  *var;
	int     fan;
	int     spill;
} rig_node_t;

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

struct list_it rig_list = {NULL, NULL};
struct list_it rig_stack = {NULL, NULL};

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
	if (!is_number(v->name[0]) && v->ssa_sub > 0)
		fprintf(f, "_%d", v->ssa_sub);
	if (v->mem_ref)
		fprintf(f, "(%s)", v->mem_ref);
}

void _print_color_var(FILE *f, var_t *v)
{
	if (v->color == 0)
		fprintf(f, "%s (spill)", v->name);
	else
		fprintf(f, "%s_r%d", v->name, v->color);
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
	} else if (p->op == 'P') {
		fprintf(f, "S%d:\t", p->line_num);
		_print_var(f, p->opr0);
		fprintf(f, " = ");
		_print_var(f, p->opr2);
		fprintf(f, " (pseudo-print)");
	}

	fprintf(f, ";");
}

static
LIST_IT_CALLBK(print_code)
{
	LIST_OBJ(struct code_t, p, ln);
	_print_code(stdout, p);
	printf("\n");
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
	if (p->mem_ref)
		free(p->mem_ref);
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

void cons_var_t(var_t *p, char *name)
{
	LIST_NODE_CONS(p->ln);
	p->name = strdup(name);
	p->ssa_sub = 0;
	p->ssa_use = 0;

	p->live_start = 0;
	p->live_end = 0;
	p->color = 0;
	p->mem_ref = NULL;
}

var_t *var_map(char *name)
{
	struct pa_id_var pa = {name, NULL};
	list_foreach(&var_list, &id_var, &pa);

	if (pa.var == NULL) {
		pa.var = malloc(sizeof(var_t));
		cons_var_t(pa.var, name);

		list_insert_one_at_tail(&pa.var->ln, &var_list, NULL, NULL);
	}

	return pa.var;
}

void code_cons(struct code_t *code, int line_num, 
		var_t *opr0, var_t *opr1, char op, var_t *opr2)
{
	LIST_NODE_CONS(code->ln);
	code->opr0 = opr0;
	code->op = op;
	code->opr1 = opr1;
	code->opr2 = opr2;
	code->line_num = line_num;
	code->dead_flag = 0;

	LIST_CONS(code->ddg_in);
	LIST_CONS(code->ddg_out);
	code->ddg_weight = 0;
	code->ddg_in_num = 0;
	
	LIST_NODE_CONS(code->ln_ready);
	LIST_NODE_CONS(code->ln_active);
	code->start_cycle = -1;
}

struct code_t *code_gen(var_t* opr0, 
		var_t* opr1, char op, var_t* opr2)
{
	struct code_t *code = malloc(sizeof(struct code_t));
	static int line_num = 0;

	code_cons(code, line_num ++, opr0, opr1, op, opr2);
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
	fprintf(cf, "\n");
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
		_print_code(stdout, s1); printf("\n"); \
		_print_code(stdout, s2); printf("\n"); \
 \
		printf("liveness in S%d: \n", s1->line_num); \
		live1 = heuristic_live(sub_list, pa_head); \
		printf("if no change: sum(liveness) = %d\n", live1); \
 \
		_stmt; \
		printf("if S%d is changed to: \n", s2->line_num); \
		_print_code(stdout, s2); printf("\n"); \
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
	
	if (s1 != s2 && s2->op != 'P') {
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
	cons_var_t(_2sa.new, p->opr0->name);

	_2sa.new->ssa_sub = p->opr0->ssa_sub + 1;
	_2sa.new->ssa_use = 1;
	if (p->opr0->mem_ref)
		_2sa.new->mem_ref = strdup(p->opr0->mem_ref);

	list_insert_one_at_tail(&_2sa.new->ln, &var_list, NULL, NULL);

	_2sa.dead = p->opr0;
	p->opr0 = _2sa.new;

	_2sa.s1 = p;
	_2sa.end_node = pa_head->last;

	/* the set of ssa_use of opr1 and opr2 
	   must precede that of opr0, here is an
	   example to explain this point:
	   a_1 = a_1 + z_1;
	*/
	if (p->opr1 != NULL) 
		p->opr1->ssa_use = 1;
	if (p->opr2 != NULL) 
		p->opr2->ssa_use = 1;
	
	if (!_2sa.dead->ssa_use) {
		/* printf("free ");
		_print_var(stdout, _2sa.dead);
		printf("...\n"); */

		list_detach_one(&_2sa.dead->ln, &var_list, NULL, NULL);
		free(_2sa.dead->name);
		if (_2sa.dead->mem_ref)
			free(_2sa.dead->mem_ref);
		free(_2sa.dead);
	}

	list_foreach(&sub_list, &_2ssa_s2, &_2sa);

	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(_set_ssa_use)
{
	LIST_OBJ(var_t, p, ln);
	p->ssa_use = 0;
	LIST_GO_OVER;
}

void code_2_ssa()
{
	list_foreach(&var_list, &_set_ssa_use, NULL);
	list_foreach(&code_list, &_2ssa_s1, NULL);
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
		code_gen(v , NULL, 'P', p);
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

	if (p->op != 'P') {
		printf("destination operator, ");
		get_liveness(p->opr0, &sub_list, &la);

		if (la.life == 0)
			p->dead_flag = 1;
	}
	
	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(_dead_eli)
{
	BOOL res;
	LIST_OBJ(struct code_t, p, ln);
	P_CAST(stop_flag, int, pa_extra);

	if (p->dead_flag) {
		res = list_detach_one(pa_now->now, 
				pa_head, pa_now, pa_fwd);

		*stop_flag = 0;
		printf("rm code:\n");
		_print_code(stdout, p);
		printf("\n");
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

	p->line_num = (*num) ++;
	
	LIST_GO_OVER;
}

static int code_dead_elimination()
{
	int num = 0;
	int stop_flag = 0;
	int cnt = 0;
	while (!stop_flag) {
		list_foreach(&code_list, &_dead_flag, NULL);
		stop_flag = 1;
		list_foreach(&code_list, &_dead_eli, &stop_flag);
		
		printf("dead code elimination %dth iteration done.\n", 
				++cnt);
	}

	printf("renumber code...\n");
	list_foreach(&code_list, &_code_renumber, &num);

	return num;
}

struct ddg_cons_arg {
	struct code_t    *s1;
	struct list_node *end_node;
};

void _add_link(struct code_t *s1, struct code_t *s2)
{
	struct ddg_li_t *li;
	printf("adding link, from S%d to S%d...\n", 
			s1->line_num, s2->line_num);

	li = malloc(sizeof(struct ddg_li_t));
	LIST_NODE_CONS(li->ln);
	li->code = s2;
	list_insert_one_at_tail(&li->ln, &s1->ddg_out, NULL, NULL);

	li = malloc(sizeof(struct ddg_li_t));
	LIST_NODE_CONS(li->ln);
	li->code = s1;
	list_insert_one_at_tail(&li->ln, &s2->ddg_in, NULL, NULL);
	s2->ddg_in_num ++;
}

static
LIST_IT_CALLBK(_ddg_cons_s2)
{
	LIST_OBJ(struct code_t, p, ln);
	P_CAST(dca, struct ddg_cons_arg, pa_extra);
	struct code_t *s1 = dca->s1, *s2 = p;
	
	if (s1->opr0 == s2->opr1 ||
		s1->opr0 == s2->opr2)
		_add_link(s1, s2);

	if (pa_now->now == dca->end_node)
		return LIST_RET_BREAK;
	else
		return LIST_RET_CONTINUE;
}

static
LIST_IT_CALLBK(_ddg_cons_s1)
{
	LIST_OBJ(struct code_t, s1, ln);
	struct ddg_cons_arg dca;
	struct list_it sub_list = list_get_it(pa_now->now);

	dca.end_node = pa_head->last;
	dca.s1 = s1;

	list_foreach(&sub_list, &_ddg_cons_s2, &dca);

	LIST_GO_OVER;
}

static void ddg_cons() 
{
	list_foreach(&code_list, &_ddg_cons_s1, NULL);
}

static
LIST_IT_CALLBK(_ddg_link_clean)
{
	BOOL res;
	LIST_OBJ(struct ddg_li_t, p, ln);
	res = list_detach_one(pa_now->now, 
			pa_head, pa_now, pa_fwd);

	free(p);
	return res;
}

static
LIST_IT_CALLBK(_ddg_clean)
{
	LIST_OBJ(struct code_t, p, ln);

	list_foreach(&p->ddg_in, &_ddg_link_clean, NULL);
	list_foreach(&p->ddg_out, &_ddg_link_clean, NULL);
	p->ddg_weight = 0;
	p->ddg_in_num = 0;

	LIST_NODE_CONS(p->ln_ready);
	LIST_NODE_CONS(p->ln_active);
	p->start_cycle = -1;

	LIST_GO_OVER;
}

static void ddg_clean() 
{
	list_foreach(&code_list, &_ddg_clean, NULL);
}

static
LIST_IT_CALLBK(_ddg_link_print)
{
	LIST_OBJ(struct ddg_li_t, p, ln);
	printf("S%d ", p->code->line_num);

	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(_ddg_print)
{
	LIST_OBJ(struct code_t, p, ln);

	printf(BOLDBLUE);
	list_foreach(&p->ddg_in, &_ddg_link_print, NULL);
	printf(ANSI_COLOR_RST);
	printf(" \t-> ");

	printf(BOLDRED);
	_print_code(stdout, p);
	printf(" (w=%d, cycle=%d, delay=%d) ", p->ddg_weight, 
			p->start_cycle, op_delay(p));
	printf(ANSI_COLOR_RST);

	printf(" \t-> ");
	printf(BOLDMAGENTA);
	list_foreach(&p->ddg_out, &_ddg_link_print, NULL);
	printf(ANSI_COLOR_RST);
	printf("\n");

	LIST_GO_OVER;
}

static void ddg_print() 
{
	list_foreach(&code_list, &_ddg_print, NULL);
}

int op_delay(struct code_t *p)
{
	int w = 0;
	switch (p->op) {
		case '+':
		case '-':
		case '=':
			w = 2;
			break;
		case '*':
			w = 4;
			break;
		case '/':
			w = 8;
			break;
		default:
			printf("bad in #%d\n", __LINE__);
	}

	return w;
}

#define MAX(_a, _b) \
	(_a) > (_b) ? (_a) : (_b)

static
LIST_IT_CALLBK(_ddg_assign_weight)
{
	LIST_OBJ(struct ddg_li_t, p, ln);
	P_CAST(father_w, int, pa_extra);
	p->code->ddg_weight = MAX(p->code->ddg_weight, 
			*father_w + op_delay(p->code));

	printf("walk by S%d\n", p->code->line_num);
	list_foreach(&p->code->ddg_in, &_ddg_assign_weight, 
			&p->code->ddg_weight);

	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(_ddg_root)
{
	LIST_OBJ(struct code_t, p, ln);

	if (p->ddg_out.now == NULL) {
		printf("assign weight from DDG root S%d...\n", 
				p->line_num);
		p->ddg_weight = op_delay(p);
		list_foreach(&p->ddg_in, &_ddg_assign_weight, 
				&p->ddg_weight);
	}

	LIST_GO_OVER;
}

static void ddg_assign_weight() 
{
	list_foreach(&code_list, &_ddg_root, NULL);
}

static
LIST_IT_CALLBK(_init_ready_li)
{
	LIST_OBJ(struct code_t, p, ln);
	P_CAST(ready_li, struct list_it, pa_extra);

	if (p->ddg_in.now == NULL)
		list_insert_one_at_tail(&p->ln_ready, ready_li, NULL, NULL);

	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(_print_ready_li)
{
	LIST_OBJ(struct code_t, p, ln_ready);

	printf("S%d(w=%d)", p->line_num, p->ddg_weight);
	
	if (pa_now->now == pa_head->last) {
		printf(".");
		return LIST_RET_BREAK;
	} else {
		printf(", ");
		return LIST_RET_CONTINUE;
	}
}

static
LIST_IT_CALLBK(_print_active_li)
{
	LIST_OBJ(struct code_t, p, ln_active);

	printf("S%d", p->line_num);
	
	if (pa_now->now == pa_head->last) {
		printf(".");
		return LIST_RET_BREAK;
	} else {
		printf(", ");
		return LIST_RET_CONTINUE;
	}
}

void ready_li_print(struct list_it *p)
{
	printf("ready list: ");
	if (p->now == NULL)
		printf("empty.");
	else 
		list_foreach(p, &_print_ready_li, NULL);
	printf("\n");
}

void active_li_print(struct list_it *p)
{
	printf("active list: ");
	if (p->now == NULL)
		printf("empty.");
	else 
		list_foreach(p, &_print_active_li, NULL);
	printf("\n");
}

static
LIST_CMP_CALLBK(_w_compare)
{
	struct code_t *p0 = MEMBER_2_STRUCT(pa_node0, 
			struct code_t, ln_ready);
	struct code_t *p1 = MEMBER_2_STRUCT(pa_node1, 
			struct code_t, ln_ready);
	P_CAST(extra, int, pa_extra);

	return p1->ddg_weight < p0->ddg_weight;
}

static
LIST_CMP_CALLBK(_l_compare)
{
	struct code_t *p0 = MEMBER_2_STRUCT(pa_node0, 
			struct code_t, ln_ready);
	struct code_t *p1 = MEMBER_2_STRUCT(pa_node1, 
			struct code_t, ln_ready);
	P_CAST(extra, int, pa_extra);

	return p1->line_num > p0->line_num;
}

static
LIST_CMP_CALLBK(_c_compare)
{
	struct code_t *p0 = MEMBER_2_STRUCT(pa_node0, 
			struct code_t, ln);
	struct code_t *p1 = MEMBER_2_STRUCT(pa_node1, 
			struct code_t, ln);

	return p1->start_cycle > p0->start_cycle;
}

struct _activity_robin_arg {
	int            *cycle;
	struct list_it *ready_li;
	int             opt;
};

static void ready_li_sort(struct _activity_robin_arg *ara)
{
	struct list_sort_arg sort;
	
	if (ara->opt)
		sort.cmp = _w_compare;
	else
		sort.cmp = _l_compare;

	list_sort(ara->ready_li , &sort);
}

static
LIST_IT_CALLBK(_ready_propagation)
{
	LIST_OBJ(struct ddg_li_t, p, ln);
	P_CAST(ara, struct _activity_robin_arg, pa_extra);
	p->code->ddg_in_num --;
	
	if (0 >= p->code->ddg_in_num) {
		printf("S%d is ready.\n", p->code->line_num);
		list_insert_one_at_tail(&p->code->ln_ready, ara->ready_li, 
				NULL, NULL);
		ready_li_sort(ara);
		
		printf("sorted, ");
		ready_li_print(ara->ready_li);

	} else {
		printf("S%d is half ready.\n", p->code->line_num);
	}

	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(_activity_robin)
{
	LIST_OBJ(struct code_t, p, ln_active);
	P_CAST(ara, struct _activity_robin_arg, pa_extra);
	int res;

	if (p->start_cycle + op_delay(p) <= *ara->cycle) {
		res = list_detach_one(pa_now->now, 
				pa_head, pa_now, pa_fwd);
		printf("S%d is off from activity list.\n", p->line_num);

		printf("doing ready-propagation.\n");
		list_foreach(&p->ddg_out, _ready_propagation, ara);

		return res;
	}
	
	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(_subseq_code)
{
	LIST_OBJ(struct code_t, p, ln);
	P_CAST(sub_code, struct code_t*, pa_extra);

	if (p->start_cycle == -1) {
		*sub_code = p;
		return LIST_RET_BREAK;
	}
	
	LIST_GO_OVER;
}

static int ddg_li_schedu(int opt)
{
	int    last_cycle = 0, cycle = 1;
	struct list_it ready_li = LIST_NULL, active_li = LIST_NULL;
	struct list_node *r_node;
	struct code_t    *r_code, *sub_code;
	struct _activity_robin_arg ara = {&cycle, &ready_li, opt};

	list_foreach(&code_list, &_init_ready_li, &ready_li);
	ready_li_sort(&ara);

	ready_li_print(&ready_li);
	active_li_print(&active_li);

	while (active_li.now != NULL 
			|| ready_li.now != NULL) {

		printf(BOLDBLUE "cycle %d:\n" ANSI_COLOR_RST, cycle);
		list_foreach(&active_li, &_activity_robin, &ara);

		r_node = ready_li.now;
		r_code = MEMBER_2_STRUCT(r_node, struct code_t, 
				ln_ready);

		if (r_node != NULL) {
			if (opt) {
				goto issue;
			} else {
				sub_code = NULL;
				list_foreach(&code_list, 
						&_subseq_code, &sub_code);
				if (sub_code != NULL)
					printf("subsequent code: S%d.\n", 
							sub_code->line_num);
				if (sub_code == r_code)
					goto issue;
			}
		}

		if (0) {
issue:
			list_detach_one(r_node, &ready_li, NULL, NULL);

			printf("issue S%d from ready list...\n", 
					r_code->line_num);

			r_code->start_cycle = cycle;
			last_cycle = cycle + op_delay(r_code);

			list_insert_one_at_tail(&r_code->ln_active, 
					&active_li, NULL, NULL);
		}

		ready_li_print(&ready_li);
		active_li_print(&active_li);

		cycle ++;
	}

	return last_cycle;
}

void code_cycle_reorder()
{
	struct list_sort_arg sort;
	int num = 0;
	sort.cmp = _c_compare;

	list_sort(&code_list , &sort);
	list_foreach(&code_list, &_code_renumber, &num);
}

struct rig_live_def_arg {
	struct list_it sub_list;
	var_t *var;
};

static
LIST_IT_CALLBK(_rig_live_def)
{
	LIST_OBJ(struct code_t, p, ln);
	P_CAST(rlda, struct rig_live_def_arg, pa_extra);

	if (p->opr0 == rlda->var) {
		rlda->sub_list = list_get_it(pa_now->now);
		return LIST_RET_BREAK;
	}
	
	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(_rig_live_cal)
{
	struct live_arg la = {0, 0, 0, NULL, code_list.last};
	LIST_OBJ(var_t, p, ln);
	struct rig_live_def_arg rlda = {code_list, p};

	if (is_number(p->name[0]))
		LIST_GO_OVER;
	else if (p->mem_ref) {
		p->live_start = 0;
		p->live_end = 0;
	
		_print_var(stdout, p);
		printf(" liveness: in memory.\n");

		LIST_GO_OVER;
	}

	list_foreach(&code_list, _rig_live_def, &rlda);
	get_liveness(p, &rlda.sub_list, &la);

	p->live_start = la.start;
	p->live_end = la.end;
	
	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(_rig_list_init)
{
	LIST_OBJ(var_t, p, ln);
	
	if (!is_number(p->name[0])) {
		rig_node_t *new = malloc(sizeof(rig_node_t));
		LIST_NODE_CONS(new->ln);
		new->var = p;
		new->fan = 0;
		new->spill = 0;

		list_insert_one_at_tail(&new->ln, &rig_list, NULL, NULL);
	}

	LIST_GO_OVER;
}

LIST_IT_CALLBK(_release_rig)
{
	BOOL res;
	LIST_OBJ(rig_node_t, p, ln);

	res = list_detach_one(pa_now->now, 
			pa_head, pa_now, pa_fwd);

	free(p);
	return res;
}

void rig_release()
{
	list_foreach(&rig_list, &_release_rig, NULL);
}

static
LIST_IT_CALLBK(_var_clean_color)
{
	LIST_OBJ(var_t, p, ln);
	p->color = 0;
	LIST_GO_OVER;
}
	
void rig_list_init()
{
	rig_release();
	list_foreach(&var_list, &_var_clean_color, NULL);
	list_foreach(&var_list, &_rig_live_cal, NULL);
	list_foreach(&var_list, &_rig_list_init, NULL);
}

static
LIST_IT_CALLBK(_rig_list_print)
{
	LIST_OBJ(rig_node_t, p, ln);
	_print_var(stdout, p->var);
	printf(": live=%d~%d, fan=%d, color=%d, ", 
			p->var->live_start, p->var->live_end, 
			p->fan, p->var->color);
	if (p->spill) 
		printf("may-spill\n");
	else
		printf("no-spill\n");

	LIST_GO_OVER;
}

void rig_print(struct list_it *li)
{
	list_foreach(li, &_rig_list_print, NULL);
}

struct rig_fan_arg {
	struct list_node *end_node;
	rig_node_t       *n1;

	int               if_color_ok;
};

static
LIST_IT_CALLBK(_rig_fan_s2)
{
	LIST_OBJ(rig_node_t, p, ln);
	P_CAST(rfa, struct rig_fan_arg, pa_extra);
	rig_node_t *n1 = rfa->n1, *n2 = p;

	if (n1 == n2) {
		goto next;
	} else if (n1->var->live_end - n1->var->live_start == 0) {
		/* skip zero-life value */
		goto next;
	} else if (n2->var->live_end - n2->var->live_start == 0) {
		/* skip zero-life value */
		goto next;
	} else if (n1->var->live_start >= n2->var->live_end ||
	    n1->var->live_end <= n2->var->live_start) {
		goto next;
	}
	
	if (n1->var->color == 0) {
		_print_var(stdout, n1->var);
		printf(" interferes with ");
		_print_var(stdout, n2->var);
		printf("\n");
	}

	if (n2->var->color != 0) /* not a spill-color */
		if (n1->var->color == n2->var->color) {
			rfa->if_color_ok = 0;

			_print_var(stdout, n1->var);
			printf(" conflicts with ");
			_print_var(stdout, n2->var);
			printf("\n");

			return LIST_RET_BREAK;
		} else {
			_print_var(stdout, n1->var);
			printf(" is ok with ");
			_print_var(stdout, n2->var);
			printf(", whose color = %d\n", n2->var->color);
		}

	n1->fan ++;
	n2->fan ++;
next:
	if (pa_now->now == rfa->end_node)
		return LIST_RET_BREAK;
	else
		return LIST_RET_CONTINUE;
}

static
LIST_IT_CALLBK(_rig_fan_s1)
{
	LIST_OBJ(rig_node_t, p, ln);
	struct list_it sub_list = list_get_it(pa_now->now);
	struct rig_fan_arg rfa = {pa_head->last, p, 0};

	list_foreach(&sub_list, &_rig_fan_s2, &rfa);

	LIST_GO_OVER;
}

static
LIST_IT_CALLBK(_rig_fan_clean)
{
	LIST_OBJ(rig_node_t, p, ln);
	p->fan = 0;

	LIST_GO_OVER;
}

void rig_list_fan_update()
{
	list_foreach(&rig_list, &_rig_fan_clean, NULL);
	list_foreach(&rig_list, &_rig_fan_s1, NULL);
}

struct rig_rm_arg {
	int K;
	int spill;
	int if_rm;
};

static
LIST_IT_CALLBK(_rig_rm)
{
	BOOL res;
	LIST_OBJ(rig_node_t, p, ln);
	P_CAST(rra, struct rig_rm_arg, pa_extra);

	if (p->fan < rra->K || rra->spill) {
		res = list_detach_one(pa_now->now, 
				pa_head, pa_now, pa_fwd);
		p->spill = rra->spill;
		p->fan = 0;

		printf("rm ");
		_print_var(stdout, p->var);
		printf("\n");

		list_insert_one_at_tail(&p->ln, &rig_stack, NULL, NULL);
		rra->if_rm ++;

		if (rra->spill)
			return LIST_RET_BREAK;
		else
			return res;
	}

	LIST_GO_OVER;
}

static int rig_rm(int spill, int K)
{
	struct rig_rm_arg rra = {K, 0, 0};
	rra.if_rm = 0;
	rra.spill = spill;
	list_foreach(&rig_list, &_rig_rm, &rra);

	if (rra.if_rm) {
		printf(BOLDMAGENTA);
		printf("%d RIG nodes have been removed " 
				"with spill=%d.\n", rra.if_rm, spill);
		printf(ANSI_COLOR_RST);

		printf("RIG stack: \n");
		rig_print(&rig_stack);

		printf("RIG list updating...\n");
		rig_list_fan_update();

		printf("RIG list after update:\n");
		rig_print(&rig_list);
	} else {
		printf(BOLDCYAN);
		printf("no RIG node can be removed "
				"with spill=%d.\n", spill);
		printf(ANSI_COLOR_RST);
	}

	return rra.if_rm;
}

void rig_forward_pass(int K)
{
	int if_rm;
	while (rig_list.now != NULL) {
		do {
			if_rm = rig_rm(0, K);
		} while (if_rm);

		rig_rm(1, K);
	}
}

int rig_reverse_pass(int K) 
{
	struct rig_fan_arg rfa;
	rig_node_t *p;
	int res = 0;

	while (rig_stack.now) {
		p = MEMBER_2_STRUCT(rig_stack.last, rig_node_t, ln);
		list_detach_one(rig_stack.last, &rig_stack, NULL, NULL);
		printf("pop ");
		_print_var(stdout, p->var);
		printf("\n");

		if (rig_list.now != NULL) {
			do {
				rfa.end_node = rig_list.last;
				rfa.n1 = p;
				rfa.if_color_ok = 1;
				p->var->color ++;
				printf("try color %d...\n", p->var->color);

				list_foreach(&rig_list, &_rig_fan_s2, &rfa);
			} while (!rfa.if_color_ok);

			if (p->spill)
				if(p->var->color > K) {
					printf("no luck, needs to be spilled.\n");
					p->var->color = 0; /* spill-color */
					res ++;
				} else 
					printf("we are lucky.\n");

		} else
			p->var->color = 1; /* first-one */

		printf(BOLDBLUE);
		printf("assign ");
		_print_var(stdout, p->var);
		printf(" with color %d.\n", p->var->color);
		printf(ANSI_COLOR_RST);

		list_insert_one_at_tail(&p->ln, &rig_list, NULL, NULL);
	}
	
	list_foreach(&rig_list, &_rig_fan_clean, NULL);
	return res;
}


static
LIST_IT_CALLBK(_var_color_print)
{
	LIST_OBJ(var_t, p, ln);
	if (!is_number(p->name[0])) {
		_print_var(stdout, p);
		printf(" : ");
		_print_color_var(stdout, p);
		printf("\n");
	}

	LIST_GO_OVER;
}

void var_color_print()
{
	list_foreach(&var_list, &_var_color_print, NULL);
}

char *mem_name()
{
	static int mem_cnt = 0;
	static char mem_nm[64];

	sprintf(mem_nm, "mem%d", mem_cnt++);
	return mem_nm;
}

static
LIST_IT_CALLBK(_spill)
{
	struct code_t *code;
	var_t *mem;
	LIST_OBJ(struct code_t, p, ln);
	struct list_it tmp_it;

	if (p->opr0 != NULL &&
	    !is_number(p->opr0->name[0]) &&
	    p->opr0->color == 0) {

		mem = var_map(mem_name());
		mem->mem_ref = strdup(p->opr0->name);

		code = malloc(sizeof(struct code_t));
		code_cons(code, 0, mem, NULL, '=', p->opr0);

		if (pa_fwd->now == pa_head->now) {
			list_insert_one_at_tail(&code->ln, pa_head,
					pa_now, pa_fwd);
			return LIST_RET_BREAK;
		} else {
			tmp_it = list_get_it(&code->ln);
			list_tk(&tmp_it, pa_fwd);
		}
	}

	if (p->opr1 != NULL &&
	    !is_number(p->opr1->name[0]) &&
	    p->opr1->color == 0 ) {

		mem = var_map(mem_name());
		mem->mem_ref = strdup(p->opr1->name);

		code = malloc(sizeof(struct code_t));
		code_cons(code, 0, p->opr1, NULL, '=', mem);

		if (pa_now->now == pa_head->now) {
			list_insert_one_at_head(&code->ln, pa_head,
					pa_now, pa_fwd);
		} else {
			tmp_it = list_get_it(&code->ln);
			list_tk(&tmp_it, pa_now);
		}
	} 

	if (p->opr2 != NULL &&
	    !is_number(p->opr2->name[0]) &&
	    p->opr2->color == 0 &&
		p->opr2 != p->opr1) {

		mem = var_map(mem_name());
		mem->mem_ref = strdup(p->opr2->name);

		code = malloc(sizeof(struct code_t));
		code_cons(code, 0, p->opr2, NULL, '=', mem);

		if (pa_now->now == pa_head->now) {
			list_insert_one_at_head(&code->ln, pa_head,
					pa_now, pa_fwd);
		} else {
			tmp_it = list_get_it(&code->ln);
			list_tk(&tmp_it, pa_now);
		}
	} 

	LIST_GO_OVER;
}

void code_spill()
{
	int num = 0;
	list_foreach(&code_list, &_spill, NULL);
	list_foreach(&code_list, &_code_renumber, &num);
	code_2_ssa();
}

#include "pseudo_test.c"

int main() 
{
	FILE *cf;
	int ncode_last, ncode = 0;
	int seq_cycles, sch_cycles;
	int K = 4;
	int spills= 0;

	if (1) 
		pseudo_test_ce_simple();
	else
		yyparse();
	
	printf("three-address code:\n"); 
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
	
	printf("adding psedu-print code...\n");
	add_psedu_print_code();

	printf("transforming to SSA...\n");
	code_2_ssa();
	
	printf("SSA form:\n"); 
	printf(BOLDRED);
	code_print(); 
	printf(ANSI_COLOR_RST);

	/*
	do {
		ncode_last = ncode;

		printf("doing code optimization...\n"); 
		code_optimization();

		printf("after code optimization:\n"); 
		printf(BOLDGREEN);
		code_print(); 
		printf(ANSI_COLOR_RST);

		printf("doing dead code elimination...\n"); 
		ncode = code_dead_elimination();

		printf("after dead code elimination...\n"); 
		printf(BOLDGREEN);
		code_print(); 
		printf(ANSI_COLOR_RST);
	} while (ncode != ncode_last);

	printf("final code after optimization:\n"); 
	printf(BOLDMAGENTA);
	code_print(); 
	printf(ANSI_COLOR_RST);
	*/

	/*
	printf("doing instruction scheduling...\n");
	printf("first do sequential simulation...\n");
	printf("constructing DDG...\n");
	ddg_cons();
	printf("DDG: \n");
	ddg_print();

	seq_cycles = ddg_li_schedu(0);
	printf(BOLDRED "total cycles: %d\n" ANSI_COLOR_RST, 
			seq_cycles);
	ddg_print();
	ddg_clean();

	printf("begin list-scheduling...\n");
	printf("constructing DDG...\n");
	ddg_cons();
	ddg_assign_weight();
	printf("DDG: \n");
	ddg_print();

	sch_cycles = ddg_li_schedu(1);
	printf("list-scheduling finished.\n");
	printf(BOLDRED "total cycles: %d\n" ANSI_COLOR_RST, 
			sch_cycles);
	ddg_print();

	printf("reorder code...\n");
	code_cycle_reorder();
	
	printf("instruction scheduling final code:\n");
	ddg_print();
	ddg_clean();

	printf("instruction scheduling saves %d - %d = %d"
	       " cycle(s) in total.\n",
			seq_cycles, sch_cycles, seq_cycles - sch_cycles);
	*/

	do {
		printf("begin liveness calculation...\n");
		rig_list_init();

		printf("update interferes...\n");
		rig_list_fan_update();

		printf("register interference graph list:\n");
		rig_print(&rig_list);

		printf("register allocation forward pass...\n");
		K = 3;
		rig_forward_pass(K);

		printf("register allocation reverse pass...\n");
		spills = rig_reverse_pass(K);

		printf(BOLDRED);
		printf("variables' color:\n"); 
		var_color_print();
		printf(ANSI_COLOR_RST);
		
		if (spills == 0) {
			printf("register allocation finished.\n");
			break;
		} else {
			printf("%d spill(s) left, ",
					spills);

			printf("spilling and converting to SSA...\n");
			code_spill();
			code_print(); 
		}
	} while (1);
	
	rig_release();
	list_foreach(&var_list, &release_var, NULL);
	list_foreach(&code_list, &release_code, NULL);

	return 0;
}
