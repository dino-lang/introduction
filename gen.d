include "ir";
expose ir.*;

fun gen (bname) {
  var h = open (bname @ ".h", "w"), c = open (bname @ ".c", "w");
  var i, vect;

  vect = vec (t2i) [0::2];
  for (i = 0; i < #vect; i++)
    fputln (h, "#define ", vect[i], "\t", i + 1);
  fputln (h);
  fputln (c, "#include \"", bname, ".h\"\n\n");
  val match_start = 3, skipif_start = match_start + #t2i,
      goto_start = skipif_start + #t2i,
      gosub_start = goto_start + (maxd - mind) + 1,
      max_code = gosub_start + (maxd - mind);
  val t = (max_code < 256 ? "unsigned char" : "unsigned short");
  fputln (c, "\nstatic ", t, " program [] = {");
  for (i = 0; i < #ns; i++) {
    pmatch (ns[i]) {
    case goto (_, lab): fput (c, " ", goto_start + l2i[lab] - i - mind, ",");
    case match (_, sym): fput (c, " ", match_start + t2i[sym], ",");
    case next (_): fput (c, " 1,");
    case ret (_): fput (c, " 2,");
    case skipif (_, sym): fput (c, " ", skipif_start + t2i[sym], ",");
    case gosub (_, lab): fput (c, " ", gosub_start + l2i[lab] - i - mind, ",");
    }
    if ((i + 1) % 10 == 0)
      fputln (c);
  }
  fputln (c, " 0, 0\n};\n\n");
  fputln (h, "extern int yylex ();\nextern int yyerror ();\n");
  fputln (h, "\nextern int yyparse ();\n");
  fputln (h, "#ifndef YYCALLSTACK_SIZE\n#define YYCALLSTACK_SIZE 50\n#endif");
  fputln (c, "\nint yyparse () {\n  int yychar = yylex (), pc = 0, code;\n  ",
	  t, " call_stack [YYCALLSTACK_SIZE];\n  ", t, " *free = call_stack;");
  fputln (c, "\n  *free++ = sizeof (program) / sizeof (program [0]) - 1;");
  fputln (c, "  while ((code = program [pc]) != 0 && yychar > 0) {");
  fputln (c, "    pc++;\n    if (code == 1)\n      yychar = yylex ();");
  fputln (c, "    else if (code == 2) /*return*/\n      pc = *--free;");
  fputln (c, "    else if ((code -= 2) < ", #t2i, ") {/*match*/");
  fputln (c, "      if (yychar == code)\n        pc++;\n      else {");
  fputln (c, "        yyerror (\"Syntax error\");\n        return 1;\n      }");
  fputln (c, "    } else if ((code -= ", #t2i, ") < ", #t2i, ") {");
  fputln (c, "      if (yychar == code)\n        pc++; /*skipif*/");
  fputln (c, "    } else if ((code -= ", #t2i, ") <= ", maxd - mind,
	  ") /*goto*/\n      pc += code + ", mind, ";");
  fputln (c, "    else if ((code -= ", maxd - mind + 1, ") <= ",
	  maxd - mind, ") { /*gosub*/");
  fputln (c, "      if (free >= call_stack + YYCALLSTACK_SIZE) {");
  fputln (c, "        yyerror (\"Call stack overflow\");");
  fputln (c, "        return 1;\n      }\n      pc += code + ", mind,
	  ";\n      *free++ = pc;\n    } else {");
  fputln (c, "      yyerror (\"Internal error\");\n      return 1;\n    }");
  fputln (c, "  }\n  if (code != 0 || yychar > 0) {");
  fputln (c, "    if (code != 0)\n      yyerror (\"Unexpected EOF\");");
  fputln (c, "    else\n      yyerror (\"Garbage after end of program\");");
  fputln (c, "    return 1;\n  }\n  return 0;\n}");
  close (h); close (c);
}
