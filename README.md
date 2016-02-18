# Introduction to Programming in Dino
## Vladimir Makarov, vmakarov@gcc.gnu.org
## Feb, 2016


*Dino* is a high-level, dynamically typed, scripting language that has
been designed for simplicity, uniformity, and expressiveness. Dino is
similar to such well known scripting languages as *Python*, *Perl*,
and *Lua*. As most programmers know the C language, Dino resembles C
where possible.

Dino is an extensible, object oriented language that has garbage
collection. It supports parallelism description, exception handling,
pattern matching, and dynamic loading of libraries written on other
languages. Although Dino works on Mac *OS X* and on *Windows* under
CYGWIN, its main platform is *Linux*.

This document is a concise introduction to the new Dino scripting
language, but is not a programmer's manual.

# Some History

Originally, Dino was designed and implemented by the Russian graphics
company
[ANIMATEK](http://www.mobygames.com/company/animatek-international-inc)
to describe the movement of dinosaurs in an animation project. (This
is origin of the language's name.) At that time it worked in only 64KB
memory. It has been considerably redesigned and reimplemented with the
aid of the COCOM toolset.

# Let's Begin

The best way to get the feel of a programming language is to see a
program written in it. Because I have worked in the compiler field for
the last 30 years, I'll write a small syntactic parser
assembler in Dino.

Most of us do not remember how programmers wrote programs for old
computers that had only a few kilobytes of memory. Long ago I read
about an Algol 60 compiler that worked on a computer that had only 420
20-bits words`[1]`. In another old book`[2]`, the author
describes an Algol compiler working on 1024 42-bits words. How did
they achieve this? One of the ways is to use an interpreter for a
specialized language; a program in a specialized language is usually
smaller. Let's implement an assembler for syntactic parsers. The
assembler output will be a syntactic parser interpreter in C. The
assembler instructions have the following format:

```
        [label:] [code [operand]]
```

Here, the constructions in brackets are optional. For convenience we
will allow comments that start with `;` and finish at the end of the
line.

The assembler will have the following instructions:

| Instruction      | Description                                         |
|------------------|-----------------------------------------------------|
| `goto` *label*   | Transfer control to the instruction marked *label*. |
|`gosub` *label*   | Transfer control to the instruction marked *label* and save the next instruction address. |
| `return`         | Transfer control to the instruction following the latest executed gosub instruction. |
|`skipif` *symbol* | If the current token is *symbol*, the following instruction is skipped. Otherwise, transfer control to the following instruction. |
| `match` *symbol* | The current token should be *symbol*, otherwise a syntax error is set. After matching, the next token is read and become the current token. |
| `next`           | The next token is read and become the current token. |

The following assembler fragment recognizes Pascal designators.

```
    ;
    ; Designator = Ident { "." Ident | "[" { expr / ","} "]" | "@" }
    ;
    start:
    Designator:
            match   Ident
    point:  skipif  Point
            goto    lbrack
            next    ; skip .
            match   Ident
            goto    point
    lbrack: skipif  LBracket
            goto    at
            next    ; skip [
    next:   gosub   expr
            skipif  Comma
            goto    rbrack
            next    ; skip ,
            goto    next
    rbrack: match   RBracket
            goto    point
    at:     skipif  At
            return
            next    ; skip @
            goto    point
```

## Overall structure of the assembler.

As a rule, assemblers work in two passes. Therefore, we need to have
some internal representation (IR) to store the program between the
passes. We will create the following Dino files:

  * The code that describes the IR and an auxiliary function will be
    in the file [`ir.d`](./ir.d).
  * The code for reading the assembler program and for generating the
    IR will be in the file [`input.d`](./input.d).
  * The code for checking the IR will be in the file [`check.d`](./check.d).
  * The code for generating the interpreter in C will be in the file
    [`gen.d`](./gen.d).
  * The top level code will be in the file [`sas.d`](./sas.d).

These files are described in detail below.

## File ir.d

This file contains the description of the IR in Dino and also some
auxiliary function. Dino has dynamic variables. In other words, a
Dino variable may contain a value of any Dino type. The major Dino
types are:

  * *characters* (Unicode characters)
  * *integers* (64-bit signed integers)
  * *long integers* (arbitrary precision signed integers)
  * *floating point numbers* (IEEE double floating point numbers)
  * *heterogeneous vectors* (that is, vectors that may contain
    elements of different types. A typical example of vector is a
    string, a vector whose values can only be characters)
  * *associative tables*
  * *objects*

The values of the last three types are **shared**. That means that if a
variable value is assigned to another variable, any changes to the
shared value through the first variable are reflected in the value of
the second variable. In general, working with shared values is
analogous to working with pointers in C, but with fewer risks.

On line 1 we see a definition of the *singleton object* `ir`.  The
class of a singleton object is anonymous and only one instance of the
class exists.  That is why such instance is called a singleton object.
Singleton objects in Dino are frequently used as name spaces.  The
object `ir` (lines 1-12) contains information about the entire
assembler program:

   * `ns`, which is initialized by an empty vector, will contain a
     vector of IR nodes that correspond to all instructions in the
     source program.
   * `l2i`, which is initialized by an empty associative table, will
     contain a table for transforming label names into an index of
     the node in `ns`. This node will represent assembler instruction
     marked by the label.
   * `i2l`, which is initialized by an empty associative table, will
     contain a table for transforming the index of the node in `ns`
     into a vector of label names. A node with such an index in `ns`
     will represent assembler instruction marked by the labels in the
     vector.
  * `ss`, which is initialized by an empty associative table, will
    contain a table of all symbols in the assembler instructions
    `match` and `skipif`.
  * `mind` and `maxd` will contain the minimum and maximum displacements
    of labels in the source program.

Inside the singleton object object `ir`, classes describing each
assembler instruction are defined.  Line 5 describes an abstract node
of an IR. A node of such class has the variable `lno` (which is the
source line of the corresponding assembler instruction). The variable
is also a class parameter. That means that you should define its value
when creating a class instance or object.

On line 6 we can see a class composition operation `use` which can
describe (multiple) inheritance, traits, and duck typing.  The
operation `use` has the following semantics:

  * Definitions of class mentioned in `use` are inlayed
  * Definitions before the `use` rewrite corresponding inlayed
    definitions mentioned in former-clause
  * Definitions after the `use` rewrite corresponding inserted
    definitions mentioned in later-clause
  * The definitions should be matched
  * The original and new definitions should be present if they are in
    former- or later-clause

To follow a common terminology, we call a class which uses definitions
of another class a sub-class of the another class.

```
     1. obj ir {                                                                                     
     2.   var ns = [], t2i = tab []; // all ir nodes, token name->token index                        
     3.   var l2i = tab [], i2l = tab []; // label -> node index -> label vector
     4.   var mind = nil, maxd = nil;                                                                
     5.   class irn (lno) {}                                                                         
     6.   class goto (lno, lab)   { use irn former lno; }                                            
     7.   class skipif (lno, sym) { use irn former lno; }                                            
     8.   class match (lno, sym)  { use irn former lno; }                                            
     9.   class gosub (lno, lab)  { use irn former lno; }                                            
    10.   class next (lno)        { use irn former lno; }                                            
    11.   class ret (lno)         { use irn former lno; }                                            
    12. }                                                                                            
    13.                                                                                              
    14. fun err (...) {                                                                              
    15.   fput (stderr, argv[0], ": ");                                                              
    16.   for (var i = 0; i < #args; i++)                                                            
    17.     if (args[i] != nil)                                                                      
    18.       fput (stderr, args[i]);                                                                
    19.   fputln (stderr);                                                                           
    20.   exit (1);                                                                                  
    21. }                                                                                            
```

Lines 14-21 contain a function to output errors. The function accepts
a variable number of parameters. Any function or class should be
called with the same number of actual parameters as the number of
formal parameters.  The number of actual parameters can be more if the
last formal parameter is "...".  The last actual parameters
corresponding to "..." will form a vector assigned to implicitly
defined variable `args`.

The other elements are:

  * The `err` function, which outputs all parameters into the standard
    error stream.
  * The `fput` function, which outputs strings, characters, integers,
    or floating point numbers
  * The `fputln` function, which is the same as `fput`, but additionally
    outputs a new line)
  * The `exit` function, which finishes the Dino program with given
    code.
  * The variables `argv`, which are all command line arguments of the
    Dino program. So `argv[0]` will be an assembler program file name.
  * `stderr` (standard error stream), which is predefined in Dino.

There are many other predefined functions, classes, and variables in
Dino. On line 16 you can see the operator `#`, which returns the number
of elements in a vector or an associative table.

Here we should say some words about the definition scope, in other
words places where the definition can be referred by its identifier.
In most cases the scope is a range between the definition point and
end of the block in which the definition is given.  The scope excludes
scopes of definitions with the same identifier in the nested blocks.
To make an useful *REPL* (an interactive Dino shell --
read-eval-print loop), another definition with the same identifier is
permitted in the same block. So the definition scope can finish
earlier before another definition with the same identifier in the same
block.

## File input.d

This file contains the function `get_ir`, which reads the file given as
its parameter, performs some checks on the file, and generates the IR
of the source program.

The first line contains an *include-clause* that specifies a source file
without the suffix **.d** (all Dino source files should have this
suffix). The file is given as a string in the clause; this means that
the entire file is inserted in place of the clause. As result, we
could check the file by calling the Dino interpreter with `input.d` on a
command line. There are several rules that define which directories
are searched for the included file. One such directory is the
directory of the file that contains the include-clause. Thus, we can
place all the assembler files in that one directory and forget about
the other rules.

The file is inserted only once in a given *block* (this is the
construction that starts with `{` and finishes with `}`). This is
important for our program because each file will contain an inclusion
of the file `ir.d`, and eventually all the files will be included into
the main program file. Unconditional inclusion in this case would
result in many error messages about repeated definitions. By the way,
there is also special form of the include-clause that permits
unconditional file inclusion.

On lines 4-13 we define some variables. Definitions can start with
keyword `var` or `val`.  Variables defined with `val` can not change
their initial value, in other words they can be considered as name
constant.  We use regular expressions to assign them strings that
describe the correct assembler lines. The regular expressions are Ruby
dialect regular expressions of
[ONIGURUMA](https://github.com/kkos/oniguruma) package.  These regular
expressions are extension of ones that are described in POSIX 10003.2.
To concatenate the strings (vectors), we use the operator `@`.

Line 15 contains a call of the special *try-function* that is used to
process *exceptional* situations in the Dino program.  Besides
try-functions Dino has *try-blocks* to process exceptions in bigger
areas.

The Dino interpreter can generate a lot of predefined exceptions. A
Dino programmer can also describe and generate other exceptions. The
exceptions are objects of the predefined class `except`, or they are
objects of a class defined inside the class `except`.

In our example, the exception we catch is "reaching the end of a
file", which is generated by the predefined function `fgetln` (reading
a new line from a file). If we do not catch the exception, the program
finishes with a diagnostic about reaching the end of the file. In the
try-function call, we write a class of exceptions that we want to
catch as the second argument. The value is the the predefined class
`eof` which is a sub-class of the class `invcall`. In turn, the class
invcall is a sub-class of the class `error` which is finally a
sub-class of the class `except`.

The predefined function `fgetln` returns the next line from the
file. After this, the line is matched with the pattern on line 17. The
predefined function `match` from the predefined singleton object `re`
returns the value `nil` if the input line does not correspond to the
pattern, otherwise it returns a vector of integer pairs. The first
pair is the first and the last character indexes in the line. The
first pair defines the substring that corresponds to the whole
pattern. The following pairs of indexes correspond to constructions in
parentheses in the pattern. They define substrings that are matched to
the constructions in the parentheses. If a construction is not matched
(for example, because an alternative is rejected), the indexes have
the value -1.

The statement on line 20 extracts a label. The predefined function
subv is used to extract the sub-vectors (sub-strings).

On lines 21 and 22, we use an empty vector to initialize a table
element that corresponds to the current assembler instruction.

On lines 23-28, we process a label, if it is defined on the line. On
lines 24-25, we check that the label is not defined repeatedly. On
line 26, we define how to map the label name into number of the
assembler instruction to which the label is bound. We make that
mapping with the aid of associative table `ir.l2i`. On line 27, we add
the label name to the vector that is the element of associative table
`ir.i2l` that has a key equal to the number of the assembler
instruction. Predefined function `ins` (insertion of element into
vector) is used with index -1, which means addition of the element at
the vector end. Dino has extensible vectors. There are also predefined
functions to delete elements in vectors (and associative tables).

```
     1. include "ir";                                                                    
     2.                                                                                  
     3. fun get_ir (f) {                                                                 
     4.   var ln, lno = 0, code, lab, op, v;                                             
     5.   // Patterns                                                                    
     6.   val p_sp = "[ \t]*";                                                           
     7.   val p_code = p_sp @ "(goto|skipif|gosub|match|return|next)";                   
     8.   val p_id = "[a-zA-Z][a-zA-Z0-9]*";                                             
     9.   val p_lab = p_sp @ "((" @ p_id @ "):)?";                                       
    10.   val p_str = "\"[^\"]*\"";                                                      
    11.   val p_op = p_sp @ "(" @ p_id @ "|" @ p_str @ ")?";                             
    12.   val p_comment = p_sp @ "(;.*)?";                                               
    13.   val pattern = "^" @ p_lab @ "(" @ p_code @ p_op @ ")?" @ p_comment @ "$";      
    14.                                                                                  
    15.   for (;try (ln = fgetln (f), eof);) {                                           
    16.     lno++;                                                                       
    17.     v = re.match (pattern, ln);                                                  
    18.     if (v == nil)                                                                
    19.       err ("syntax error on line ", lno);                                        
    20.     lab = (v[4] >= 0 ? subv (ln, v[4], v[5] - v[4]) : nil);                      
    21.     if (!(#ir.ns in ir.i2l))                                                     
    22.       ir.i2l[#ir.ns] = [];                                                       
    23.     if (lab != nil) {                                                            
    24.       if (lab in ir.l2i)                                                         
    25.         err ("redefinition lab ", lab, " on line ", lno);                        
    26.       ir.l2i[lab] = #ir.ns;                                                      
    27.       ins (ir.i2l [#ir.ns], lab, -1);                                            
    28.     }                                                                            
    29.     code = (v[8] >= 0 ? subv (ln, v[8], v[9] - v[8]) : nil);                     
    30.     if (code == nil)                                                             
    31.       continue;  // skip comment or absent code                                  
    32.     op = (v[10] >= 0 ? subv (ln, v[10], v[11] - v[10]) : nil);                   
    33.     var node;                                                                    
    34.     if (code == "goto" || code == "gosub") {                                     
    35.       if (op == nil || re.match (p_id, op) == nil)                               
    36.         err ("invalid or absent lab `", op, "' on line ", lno);                  
    37.       node = (code == "goto" ? ir.goto (lno, op) :  ir.gosub (lno, op));         
    38.     } else if (code == "skipif" || code == "match") {                            
    39.       if (op == nil || re.match (p_id, op) == nil)                               
    40.         err ("invalid or absent name `", op, "' on line ", lno);                 
    41.       node = (code == "skipif" ? ir.skipif (lno, op) : ir.match (lno, op));      
    42.     } else if (code == "return" || code == "next") {                             
    43.       if (op != nil)                                                             
    44.         err (" non empty operand `", op, "' on line ", lno);                     
    45.       node = (code == "next" ? ir.next (lno) : ir.ret (lno));                    
    46.     }                                                                            
    47.     ins (ir.ns, node, -1);                                                       
    48.   }                                                                              
    49. }
```

On lines 34-46 we check the current assembler instruction and create
the corresponding IR node (an object of a class inside the singleton
object `ir` -- see file `ir.d`). And finally, we insert the node at
the end of the vector `ir.ns` (line 47).

## File check.d

After processing all assembler instructions in the file `input.d`, we
can check that all labels are defined (lines 9-10) and we can evaluate
the maximum and minimum displacements of `goto` and `gosub`
instructions from the corresponding label definition (lines
11-14). The function `check` makes this work. It also forms an
associative table `ir.ss` of all symbols given in the instructions
`match` and `skipif`, and enumerates the symbols (lines 6-7). Here the
function `isa` (lines 6 and 8) is used to define that an object is of
a given class, or of a sub-class of a given class.

```
     1. include "ir";                                                                
     2.                                                                              
     3. fun check {                                                                  
     4.   for (var i = 0; i < #ir.ns; i++) {                                         
     5.     val n = ir.ns[i];                                                        
     6.     if ((isa (n, ir.match) || isa (n, ir.skipif)) && !(n.sym in ir.t2i))     
     7.       ir.t2i[n.sym] = #ir.t2i;                                               
     8.     else if (isa (n, ir.goto) || isa (n, ir.gosub)) {                        
     9.       if (!(n.lab in ir.l2i))                                                
    10.         err ("undefined label `", n.lab, "' on line ", n.lno);               
    11.       if (ir.maxd == nil || ir.maxd < ir.l2i[n.lab] - i)                     
    12.         ir.maxd = ir.l2i[n.lab] - i;                                         
    13.       if (ir.mind == nil || ir.mind > ir.l2i[n.lab] - i)                     
    14.         ir.mind = ir.l2i[n.lab] - i;                                         
    15.     }                                                                        
    16.   }                                                                          
    17. }
```

## File gen.d

The biggest assembler source file is the interpreter generator.  To
make the code more brief and to permit referring for the definitions
of the singleton object `ir` without using prefix `ir.`, we expose all
definitions (line 2).  In general the clause `expose` can expose all
or only specific definitions, even using their new names.

Dino has a few standard singleton objects which contains the rest of
standard definitions.  All definitions inside standard objects `lang`
and `io` are always exposed.  Therefore we refer for some most
frequenlty used standard definitions, e.g. `argv` or `fput`, without
mentioning objects in which they defined.

In file `gen.d` we generates two files: a `.h` file (the interface of
the interpreter) and a `.c` file (the interpreter itself). We create
the files on line 5. The parameter `bname` of the function `gen` is a
base name of the generated files. The interface file contains
definitions of codes of tokens in `match` and `skipif` instructions as
C macros (line 10) and definition of function `yyparse` (line
33). Function `yyparse` is a main interpreter function. It returns 0
if the source program is correct, and nonzero otherwise.

The generated interpreter requires the external functions `yylex` and
`yyerror` (line 32). The function `yylex` is used by the interpreter to
read and to get the code of the current token. Function `yyerror` should
output error diagnostics. (The interface is a simplified version of
the Yacc Unix Utility interface.)

The compiled assembler program is presented by a C array of chars or
short integers with the name `program`. Each element of the array is
an encoded instruction of the source program. On lines 13-17, we
evaluate the start code for each kind of assembler instruction and
define the type of array elements.

On lines 18-31, we output the array `program`.  To differ IR nodes we
use *pattern-matching* (see `pmatch`-statement).  Pattern matching is
a powerful technique to work with objects, vectors, and tables.  It
permits to assign parts of the matched value to *pattern variables*.
For example, on line 21 we assigns the second parameter value of class
`goto` object to implicitly defined variable `lab` and use it in the
statements corresponding to given case.

On lines 35-58, we output the function `yyparse`. Finally, on line 59
we close the two output files with the aid of the predefined function
`close`.

```
     1. include "ir";                                                                      
     2. expose ir.*;                                                                       
     3.                                                                                    
     4. fun gen (bname) {                                                                  
     5.   var h = open (bname @ ".h", "w"), c = open (bname @ ".c", "w");                  
     6.   var i, vect;                                                                     
     7.                                                                                    
     8.   vect = vec (t2i) [0::2];                                                         
     9.   for (i = 0; i < #vect; i++)                                                      
    10.     fputln (h, "#define ", vect[i], "\t", i + 1);                                  
    11.   fputln (h);                                                                      
    12.   fputln (c, "#include \"", bname, ".h\"\n\n");                                    
    13.   val match_start = 3, skipif_start = match_start + #t2i,                          
    14.       goto_start = skipif_start + #t2i,                                            
    15.       gosub_start = goto_start + (maxd - mind) + 1,                                
    16.       max_code = gosub_start + (maxd - mind);                                      
    17.   val t = (max_code < 256 ? "unsigned char" : "unsigned short");                   
    18.   fputln (c, "\nstatic ", t, " program [] = {");                                   
    19.   for (i = 0; i < #ns; i++) {                                                      
    20.     pmatch (ns[i]) {                                                               
    21.     case goto (_, lab): fput (c, " ", goto_start + l2i[lab] - i - mind, ",");      
    22.     case match (_, sym): fput (c, " ", match_start + t2i[sym], ",");               
    23.     case next (_): fput (c, " 1,");                                                
    24.     case ret (_): fput (c, " 2,");                                                 
    25.     case skipif (_, sym): fput (c, " ", skipif_start + t2i[sym], ",");             
    26.     case gosub (_, lab): fput (c, " ", gosub_start + l2i[lab] - i - mind, ",");    
    27.     }                                                                              
    28.     if ((i + 1) % 10 == 0)                                                         
    29.       fputln (c);                                                                  
    30.   }                                                                                
    31.   fputln (c, " 0, 0\n};\n\n");                                                     
    32.   fputln (h, "extern int yylex ();\nextern int yyerror ();\n");                    
    33.   fputln (h, "\nextern int yyparse ();\n");                                        
    34.   fputln (h, "#ifndef YYCALLSTACK_SIZE\n#define YYCALLSTACK_SIZE 50\n#endif");     
    35.   fputln (c, "\nint yyparse () {\n  int yychar = yylex (), pc = 0, code;\n  ",     
    36.           t, " call_stack [YYCALLSTACK_SIZE];\n  ", t, " *free = call_stack;");    
    37.   fputln (c, "\n  *free++ = sizeof (program) / sizeof (program [0]) - 1;");        
    38.   fputln (c, "  while ((code = program [pc]) != 0 && yychar > 0) {");              
    39.   fputln (c, "    pc++;\n    if (code == 1)\n      yychar = yylex ();");           
    40.   fputln (c, "    else if (code == 2) /*return*/\n      pc = *--free;");           
    41.   fputln (c, "    else if ((code -= 2) < ", #t2i, ") {/*match*/");                 
    42.   fputln (c, "      if (yychar == code)\n        pc++;\n      else {");            
    43.   fputln (c, "        yyerror (\"Syntax error\");\n        return 1;\n      }");   
    44.   fputln (c, "    } else if ((code -= ", #t2i, ") < ", #t2i, ") {");               
    45.   fputln (c, "      if (yychar == code)\n        pc++; /*skipif*/");               
    46.   fputln (c, "    } else if ((code -= ", #t2i, ") <= ", maxd - mind,               
    47.           ") /*goto*/\n      pc += code + ", mind, ";");                           
    48.   fputln (c, "    else if ((code -= ", maxd - mind + 1, ") <= ",                   
    49.           maxd - mind, ") { /*gosub*/");                                           
    50.   fputln (c, "      if (free >= call_stack + YYCALLSTACK_SIZE) {");                
    51.   fputln (c, "        yyerror (\"Call stack overflow\");");                        
    52.   fputln (c, "        return 1;\n      }\n      pc += code + ", mind,              
    53.           ";\n      *free++ = pc;\n    } else {");                                 
    54.   fputln (c, "      yyerror (\"Internal error\");\n      return 1;\n    }");       
    55.   fputln (c, "  }\n  if (code != 0 || yychar > 0) {");                             
    56.   fputln (c, "    if (code != 0)\n      yyerror (\"Unexpected EOF\");");           
    57.   fputln (c, "    else\n      yyerror (\"Garbage after end of program\");");       
    58.   fputln (c, "    return 1;\n  }\n  return 0;\n}");                                
    59.   close (h); close (c);                                                            
    60. }
```

## File sas.d

This is the main assembler file. Lines 1-4 are include-clauses for the
inclusion of the previous files. Line 6-7 checks that the argument is
given on the command line. On line 9 we open the file given on the
command line, and call the function for reading and generating the IR
of the program. If the file does not exist or cannot be opened for
reading, an exception is generated. The exception results in the
output of standard diagnostics and finishes the program. We could
catch the exception and do something else, but the standard
diagnostics will be sufficient here. On line 10, we check the IR.

And finally on line 11, we generate the interpreter of the program. To
get the base name of the assembler file, we use the predefined
function `sub` from standard singleton object `re`, deleting all
directories and suffixes from the file name and returning the result.
Regular expressions frequently use `/` which is also an escape prefix
in a regular string constant.  To avoid complicated regular string
constants, we use another form of a string constant without any escape
characters.  Such strings start and finish with a back qoute
character.

```
     1. include "ir";                                          
     2. include "input";                                       
     3. include "check";                                       
     4. include "gen";                                         
     5.                                                        
     6. if (#argv != 1)                                        
     7.   err ("Usage: sas file");                             
     8.                                                        
     9. get_ir (open (argv[0], "r"));                          
    10. check ();                                              
    11. gen (re.sub (`^(.*/)?([^.]*)(\..*)?$`, argv[0], `\2`));
```

## Results

So we've written the assembler (this is 158 lines in Dino). As a test,
we will use Oberon-2 language grammar. You can look at Oberon-2 parser
in the file [`oberon2.sas`](./oberon2.sas). After

```
        dino sas.d oberon2.sas
```
we will get two files oberon2.h and oberon2.c. Let's look at the size
of generated x86-64 code:

```
        gcc -c oberon2.c; size oberon2.o

           text    data     bss     dec     hex filename
            579     934       0    1513     5e9 oberon2.o
```

For comparison, we would have about 15Kb for a YACC generated
parser. Not bad. But we could make the parser even less than 1Kb by
using short and long goto and gosub instructions. Actually, what we
generate is not a parser, it is only a recognizer. But the assembler
language could be easily extended to write parsers. Just add the
instructions:

```
       call C-function-name
```

to call semantic functions for the generation of parsed code. In any
case, most of a compiler's code would be in C. To further decrease the
compiler size (not only its parser), an interpreter of C that is
specialized to the compiler could be written.

Of course, it is not easy work to write a parser on the assembler. So
we could generate assembler code from a high-level syntax description,
for example, from a Backus-Naur form. Another area for improvement is
the implementation of error recovery, but this was not our
purpose. Our goal was just to demonstrate the Dino language.

# Some last comments

What Dino's features were missed in this introduction? Many details,
of course, but we also have not described the following major parts of
Dino language:

  * Threads
  * Public and private variables
  * Mutable and immutable values
  * Anonymous functions, classes, threads
  * Closures and higher order functions
  * Regular expression match-statement
  * Interface with C language and writing external dynamic libraries

The Dino interpreter is distributed under GNU Public license. You can
find it on

[https://github.com/dino-lang/dino](https://github.com/dino-lang/dino)

------------------------------------------------------------------------

`[1]`: "Algol 60 Implementation" by B. Randell and L.J. Russel,
Academic Press, 1964.

`[2]`: "Compiler Construction for Digital Computers", David Gries,
John Wiley & Sons, 1971.

------------------------------------------------------------------------

Copyright © 2016, Vladimir N. Makarov
