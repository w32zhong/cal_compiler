void pseudo_test_cse_1()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	_3_addr_code_gen(a , b, '+', c);
	_3_addr_code_gen(d , b, '+', c);
}

void pseudo_test_cse_2()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	_3_addr_code_gen(a , NULL, '=', d);
	_3_addr_code_gen(b , c, '+', d);
}

void pseudo_test_cse_3()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	_3_addr_code_gen(a , NULL, '=', d);
	_3_addr_code_gen(b , NULL, '=', d);
}

void pseudo_test_cse_4()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	_3_addr_code_gen(a , NULL, '-', d);
	_3_addr_code_gen(b , NULL, '-', d);
}

void pseudo_test_cse_5()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	_3_addr_code_gen(a , NULL, '=', d);
	_3_addr_code_gen(b , NULL, '-', d);
}

void pseudo_test_ce_1()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	_3_addr_code_gen(a , b, '+', c);
	_3_addr_code_gen(d , NULL, '=', a);
}

void pseudo_test_ce_2()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	_3_addr_code_gen(a , NULL, '=', d);
	_3_addr_code_gen(b , c, '+', a);
}

void pseudo_test_ce_3()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	_3_addr_code_gen(a , NULL, '=', d);
	_3_addr_code_gen(b , NULL, '=', a);
}

void pseudo_test_ce_4()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	_3_addr_code_gen(a , NULL, '=', d);
	_3_addr_code_gen(b , NULL, '-', a);
}

void pseudo_test_ce_5()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	_3_addr_code_gen(a , NULL, '-', d);
	_3_addr_code_gen(b , NULL, '=', a);
}

void pseudo_test_ce_simple()
{
	var_t *tmp = var_map("tmp");
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	_3_addr_code_gen(tmp , a, '+', b);
	_3_addr_code_gen(c , NULL, '=', tmp);
	_3_addr_code_gen(d , a, '+', b);
}

void pseudo_test_cse_simple()
{
	var_t *a = var_map("a");
	var_t *b = var_map("b");
	var_t *c = var_map("c");
	var_t *d = var_map("d");
	var_t *_2 = var_map("2");
	_3_addr_code_gen(a , b, '+', c);
	_3_addr_code_gen(d , b, '+', c);
	_3_addr_code_gen(b , NULL, '=', _2);
	_3_addr_code_gen(c , NULL, '=', _2);
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
	_3_addr_code_gen(x , NULL, '=', _2);
	_3_addr_code_gen(y , NULL, '=', _2);
	_3_addr_code_gen(z , NULL, '=', x);
	_3_addr_code_gen(p , x, '+', _2);
	_3_addr_code_gen(z2 , y, '+', p);
	_3_addr_code_gen(y2 , NULL, '=', p);
	_3_addr_code_gen(x2 , NULL, '=', x);
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
	var_t *i = var_map("i");
	var_t *z = var_map("z");
	_3_addr_code_gen(a , a, '+', z);
	_3_addr_code_gen(b , z, '+', a);
	_3_addr_code_gen(c , a, '*', _3);
	_3_addr_code_gen(d , a, '-', _3);
	_3_addr_code_gen(e , _3, '/', a);
	_3_addr_code_gen(f , b, '*', c);
	_3_addr_code_gen(g , d, '-', e);
	_3_addr_code_gen(h , f, '*', g);
	_3_addr_code_gen(i , b, '*', b);
}

void pseudo_test_spill()
{
	var_t *a = var_map("a");
	a->color = 0;
	var_t *b = var_map("b");
	b->color = 1;
	var_t *c = var_map("c");
	c->color = 0;

	_3_addr_code_gen(b , a, '+', a);
	_3_addr_code_gen(a , a, '+', b);
	_3_addr_code_gen(a , a, '+', c);
	_3_addr_code_gen(a , b, '+', b);
}
