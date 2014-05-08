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

void pseudo_test_ce_simple()
{
	var_t *tmp = var_map("tmp0");
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	code_gen(tmp , a, '+', b);
	code_gen(c , NULL, '=', tmp);
}

void pseudo_test_cse_simple()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	var_t *_2 = var_map("2");
	code_gen(a , b, '+', c);
	code_gen(d , b, '+', c);
	code_gen(b , NULL, '=', _2);
	code_gen(c , NULL, '=', _2);
}

void pseudo_test_ddg()
{
	var_t *_2 = var_map("2");
	var_t *x = var_map("x");
	var_t *y = var_map("y");
	var_t *z = var_map("z");
	var_t *p = var_map("p");
	var_t *x2 = var_map("x2");
	var_t *y2 = var_map("y2");
	var_t *z2 = var_map("z2");
	code_gen(x , NULL, '=', _2);
	code_gen(y , NULL, '=', _2);
	code_gen(z , NULL, '=', x);
	code_gen(p , x, '+', _2);
	code_gen(z2 , y, '+', p);
	code_gen(y2 , NULL, '=', p);
	code_gen(x2 , NULL, '=', x);
}

void pseudo_test_rig()
{
	var_t *_3 = var_map("3");
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	var_t *e = var_map("e");
	var_t *f = var_map("f");
	var_t *g = var_map("g");
	var_t *h = var_map("h");
	code_gen(a , NULL, '=', _3);
	code_gen(b , a, '+', _3);
	code_gen(c , a, '*', _3);
	code_gen(d , a, '-', _3);
	code_gen(e , a, '/', _3);
	code_gen(f , b, '*', c);
	code_gen(g , d, '-', e);
	code_gen(h , f, '*', g);
}
