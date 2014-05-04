void pseudo_test_cse_1()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	code_gen(a , b, '+', c);
	code_gen(d , b, '+', c);
}

void pseudo_test_cse_2()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	code_gen(a , NULL, '=', d);
	code_gen(b , c, '+', d);
}

void pseudo_test_cse_3()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	code_gen(a , NULL, '=', d);
	code_gen(b , NULL, '=', d);
}

void pseudo_test_cse_4()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	code_gen(a , NULL, '-', d);
	code_gen(b , NULL, '-', d);
}

void pseudo_test_cse_5()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	code_gen(a , NULL, '=', d);
	code_gen(b , NULL, '-', d);
}

void pseudo_test_ce_1()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	code_gen(a , b, '+', c);
	code_gen(d , NULL, '=', a);
}

void pseudo_test_ce_2()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	code_gen(a , NULL, '=', d);
	code_gen(b , c, '+', a);
}

void pseudo_test_ce_3()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	code_gen(a , NULL, '=', d);
	code_gen(b , NULL, '=', a);
}

void pseudo_test_ce_4()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	code_gen(a , NULL, '=', d);
	code_gen(b , NULL, '-', a);
}

void pseudo_test_ce_5()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	code_gen(a , NULL, '-', d);
	code_gen(b , NULL, '=', a);
}
