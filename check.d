include "ir";

fun check {
  for (var i = 0; i < #ir.ns; i++) {
    val n = ir.ns[i];
    if ((isa (n, ir.match) || isa (n, ir.skipif)) && !(n.sym in ir.t2i))
      ir.t2i[n.sym] = #ir.t2i;
    else if (isa (n, ir.goto) || isa (n, ir.gosub)) {
      if (!(n.lab in ir.l2i))
	err ("undefined label `", n.lab, "' on line ", n.lno);
      if (ir.maxd == nil || ir.maxd < ir.l2i[n.lab] - i)
	ir.maxd = ir.l2i[n.lab] - i;
      if (ir.mind == nil || ir.mind > ir.l2i[n.lab] - i)
	ir.mind = ir.l2i[n.lab] - i;
    }
  }
}
