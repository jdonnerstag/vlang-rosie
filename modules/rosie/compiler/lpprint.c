/*
** $Id: lpprint.c,v 1.9 2015/06/15 16:09:57 roberto Exp $
** Copyright 2007, Lua.org & PUC-Rio  (see 'lpeg.html' for license)
*/

#include <ctype.h>
#include <limits.h>
#include <stdio.h>


#include "lptypes.h"
#include "lpprint.h"
#include "lpcode.h"
#include "vm.h"


#if defined(LPEG_DEBUG)

/*
** {======================================================
** Printing patterns (for debugging)
** =======================================================
*/


void printcharset (const byte *st) {
  int i;
  printf("[");
  for (i = 0; i <= UCHAR_MAX; i++) {
    int first = i;
    while (testchar(st, i) && i <= UCHAR_MAX) i++;
    if (i - 1 == first)  /* unary range? */
      printf("(%02x)", first);
    else if (i - 1 > first)  /* non-empty range? */
      printf("(%02x-%02x)", first, i - 1);
  }
  printf("]");
}


static void printcapkind (int kind) {
  printf("%s", CAPTURE_NAME(kind));
}


static void printjmp (const Instruction *op, const Instruction *p) {
  printf("-> %d", (int)(p + addr(p) - op));
}


void printinst (const Instruction *op, const Instruction *p) {
  printf("%02ld: %s ", (long)(p - op), OPCODE_NAME(opcode(p)));
  switch ((Opcode) opcode(p)) {
    case IChar: {
      printf("'%c'", ichar(p));
      break;
    }
    case ITestChar: {
      printf("'%c'", ichar(p)); printjmp(op, p);
      break;
    }
    case IOpenCapture: {
      printcapkind(addr(p));
      printf(" (idx = %d)", index(p));
      if (addr(p) == Crosieconst)
	printf("  (data = %d)", addr(p) + 1);
      break;
    }
    case IBackref: {
      printcapkind(Cbackref);
      printf(" (idx = %d)", index(p));
      break;
    }
    case ISet: {
      printcharset((p+1)->buff);
      break;
    }
    case ITestSet: {
      printcharset((p+2)->buff); printjmp(op, p);
      break;
    }
    case ISpan: {
      printcharset((p+1)->buff);
      break;
    }
    case IOpenCall: {
      printf("-> %d", addr(p));
      break;
    }
    case IBehind: {
      printf("%d", addr(p));
      break;
    }
    case IJmp: case ICall: case ICommit: case IChoice:
    case IPartialCommit: case IBackCommit: case ITestAny: {
      printjmp(op, p);
      break;
    }
    default: break;
  }
  printf("\n");
}


void printpatt (Instruction *p, int n) {
  Instruction *op = p;
  while (p < op + n) {
    printinst(op, p);
    p += sizei(p);
  }
}

void printcode (Instruction *p) {
  Instruction *op = p;
  while (1) {
    printinst(op, p);
    if (opcode(p) == IEnd) break;
    p += sizei(p);
  }
}


#if defined(LPEG_DEBUG)
static void printcap (Capture *cap) {
  printcapkind(capkind(cap));
  /* the cast below is to suppress warning */
  printf(" (idx: %d) -> %p\n", capidx(cap), (const void *) cap->s);
}


void printcaplist (Capture *cap, Capture *limit) {
  printf(">======\n");
  for (; cap->s && (limit == NULL || cap < limit); cap++)
    printcap(cap);
  printf("=======\n");
}
#endif

/* }====================================================== */


/*
** {======================================================
** Printing trees (for debugging)
** =======================================================
*/

static const char *tagnames[] = {
  "char", "set", "any",
  "true", "false",
  "rep",
  "seq", "choice",
  "not", "and",
  "call", "opencall", "rule", "grammar",
  "behind",
  "capture", "run-time",
  "halt"
};


void printtree (TTree *tree, int ident) {
  int i;
  for (i = 0; i < ident; i++) printf(" ");
  printf("%s", tagnames[tree->tag]);
  switch (tree->tag) {
    case TChar: {
      int c = tree->u.n;
      if (isprint(c))
        printf(" '%c'\n", c);
      else
        printf(" (%02X)\n", c);
      break;
    }
    case TSet: {
      printcharset(treebuffer(tree));
      printf("\n");
      break;
    }
    case TOpenCall: case TCall: {
      printf(" key: %d\n", tree->key);
      break;
    }
    case TBehind: {
      printf(" %d\n", tree->u.n);
        printtree(sib1(tree), ident + 2);
      break;
    }
    case TCapture: {
      //      printf(" cap: %d  key: %d  n: %d\n", tree->cap, tree->key, tree->u.n);
      printf(" kind: %d  key: %d  key2: %d\n", tree->cap, tree->key, tree->u.n);
      printtree(sib1(tree), ident + 2);
      break;
    }
    case TRule: {
      printf(" n: %d  key: %d\n", tree->cap, tree->key);
      printtree(sib1(tree), ident + 2);
      break;  /* do not print next rule as a sibling */
    }
    case TGrammar: {
      TTree *rule = sib1(tree);
      printf(" %d\n", tree->u.n);  /* number of rules */
      for (i = 0; i < tree->u.n; i++) {
        printtree(rule, ident + 2);
        rule = sib2(rule);
      }
      assert(rule->tag == TTrue);  /* sentinel */
      break;
    }
    default: {
      int sibs = numsiblings[tree->tag];
      printf("\n");
      if (sibs >= 1) {
        printtree(sib1(tree), ident + 2);
        if (sibs >= 2)
          printtree(sib2(tree), ident + 2);
      }
      break;
    }
  }
}


void printktable (Ktable *kt) {
  int n, i;
  if (!kt)			/* no ktable? */
    return;
  n = ktable_len(kt);
  printf("[");
  for (i = 1; i <= n; i++) {
    size_t len;
    const char *name = ktable_element_name(kt, i, &len);
    printf("%d = ", i);
    printf("%.*s  ", (int) len, name);
  }
  printf("]\n");
}

/* }====================================================== */

#endif
