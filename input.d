include "ir";

fun get_ir (f) {
  var ln, lno = 0, code, lab, op, v;
  // Patterns
  val p_sp = "[ \t]*";
  val p_code = p_sp @ "(goto|skipif|gosub|match|return|next)";
  val p_id = "[a-zA-Z][a-zA-Z0-9]*";
  val p_lab = p_sp @ "((" @ p_id @ "):)?";
  val p_str = "\"[^\"]*\"";
  val p_op = p_sp @ "(" @ p_id @ "|" @ p_str @ ")?";
  val p_comment = p_sp @ "(;.*)?";
  val pattern = "^" @ p_lab @ "(" @ p_code @ p_op @ ")?" @ p_comment @ "$";

  for (;try (ln = fgetln (f), eof);) {
    lno++;
    v = re.match (pattern, ln);
    if (v == nil)
      err ("syntax error on line ", lno);
    lab = (v[4] >= 0 ? subv (ln, v[4], v[5] - v[4]) : nil);
    if (!(#ir.ns in ir.i2l))
      ir.i2l[#ir.ns] = [];
    if (lab != nil) {
      if (lab in ir.l2i)
        err ("redefinition lab ", lab, " on line ", lno);
      ir.l2i[lab] = #ir.ns;
      ins (ir.i2l [#ir.ns], lab, -1);
    }
    code = (v[8] >= 0 ? subv (ln, v[8], v[9] - v[8]) : nil);
    if (code == nil)
      continue;  // skip comment or absent code
    op = (v[10] >= 0 ? subv (ln, v[10], v[11] - v[10]) : nil);
    var node;
    if (code == "goto" || code == "gosub") {
      if (op == nil || re.match (p_id, op) == nil)
        err ("invalid or absent lab `", op, "' on line ", lno);
      node = (code == "goto" ? ir.goto (lno, op) :  ir.gosub (lno, op));
    } else if (code == "skipif" || code == "match") {
      if (op == nil || re.match (p_id, op) == nil)
  	err ("invalid or absent name `", op, "' on line ", lno);
      node = (code == "skipif" ? ir.skipif (lno, op) : ir.match (lno, op));
    } else if (code == "return" || code == "next") {
      if (op != nil)
  	err (" non empty operand `", op, "' on line ", lno);
      node = (code == "next" ? ir.next (lno) : ir.ret (lno));
    }
    ins (ir.ns, node, -1);
  }
}
