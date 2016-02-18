obj ir {
  var ns = [], t2i = tab []; // all ir nodes, token name->token index
  var l2i = tab [], i2l = tab []; // label -> node index -> label vector
  var mind = nil, maxd = nil;
  class irn (lno) {}
  class goto (lno, lab)   { use irn former lno; }
  class skipif (lno, sym) { use irn former lno; }
  class match (lno, sym)  { use irn former lno; }
  class gosub (lno, lab)  { use irn former lno; }
  class next (lno)        { use irn former lno; }
  class ret (lno)         { use irn former lno; }
}

fun err (...) {
  fput (stderr, argv[0], ": ");
  for (var i = 0; i < #args; i++)
    if (args[i] != nil)
      fput (stderr, args[i]);
  fputln (stderr);
  exit (1);
}
