/*
 * as_macro.c — Macro system for the Z80 assembler
 *
 * Implements MACRO/ENDM definitions, macro expansion with parameter
 * substitution, REPT/IRP/IRPC repetition directives, LOCAL symbols,
 * EXITM, and & (ampersand) concatenation.
 *
 * Macro bodies are stored in a linked-list pool of 32-byte blocks.
 * Each block: [2-byte prev ptr][2-byte next ptr][28 bytes of text]
 *
 * Ported from ASM1.ASM: A298C, A30E3, A2EC8, A2FA1, A31C5, A3363, etc.
 */

#include "as_defs.h"

/* ----------------------------------------------------------------
 *  Macro body stream — block-based linked list storage
 *
 *  Block layout (32 bytes):
 *    +0..+1  : link to previous block (u16 offset in memory[])
 *    +2..+3  : link to next block (u16 offset in memory[])
 *    +4..+31 : 28 bytes of text data
 *
 *  Position encoding (mem_alloc_ptr / D399D):
 *    bits 0-4 : offset within block (0..31, data at 4..31)
 *    bits 5+  : block selector (added to mem_pool_start)
 * ---------------------------------------------------------------- */

#define MACRO_BLOCK_SIZE  32
#define MACRO_DATA_OFFSET  4
#define MACRO_DATA_PER_BLOCK (MACRO_BLOCK_SIZE - MACRO_DATA_OFFSET)

/* Max parameters per macro */
#define MAX_MACRO_PARAMS   32
/* Max macro body size (chars) */
#define MAX_MACRO_BODY    8192
/* Max nesting depth */
#define MAX_MACRO_NEST     16
/* Max LOCAL symbols per expansion */
#define MAX_LOCAL_SYMS     64

/* ----------------------------------------------------------------
 *  Macro definition storage
 * ---------------------------------------------------------------- */

typedef struct MacroParam {
    u8   name[MAX_ID_LEN + 1];
    u8   namelen;
} MacroParam;

typedef struct MacroDef {
    u8   name[MAX_ID_LEN + 1];
    u8   namelen;
    int  nparams;
    MacroParam params[MAX_MACRO_PARAMS];
    char *body;        /* dynamically allocated body text, lines separated by \n */
    int   body_len;
    u16   sym_offset;  /* offset in symbol table */
} MacroDef;

/* Storage for defined macros */
#define MAX_MACROS 128
static MacroDef macros[MAX_MACROS];
static int      macro_count = 0;

/* ----------------------------------------------------------------
 *  Expansion state (nested stack)
 * ---------------------------------------------------------------- */

typedef struct MacroExpansion {
    MacroDef *def;           /* which macro we're expanding */
    char     *args[MAX_MACRO_PARAMS]; /* argument strings */
    int       nargs;
    int       body_pos;      /* current read position in body */
    int       repeat_count;  /* remaining repetitions (REPT) */
    int       repeat_total;  /* original repeat count */
    u16       local_base;    /* base counter for LOCAL symbols */
    int       is_rept;       /* 1=REPT, 0=MACRO call */
    char     *irp_list;      /* IRP value list */
    int       irp_pos;       /* current position in irp_list */
    int       is_irp;        /* 1=IRP */
    int       is_irpc;       /* 1=IRPC */
    char      irpc_str[256]; /* IRPC string */
    int       irpc_idx;      /* current char index */
    char      irp_param[MAX_ID_LEN + 1]; /* IRP/IRPC parameter name */
    u8        irp_param_len;
} MacroExpansion;

static MacroExpansion expansion_stack[MAX_MACRO_NEST];
static int expansion_depth = 0;

/* Local symbol counter (globally incrementing) */
static u16 local_sym_counter = 0;

/* Line buffer for macro expansion output */
static char macro_line_buf[LINE_BUF_SIZE];
static int  macro_line_len = 0;
static int  macro_line_pos = 0;
static int  macro_active = 0;  /* non-zero when reading from macro expansion */

/* ----------------------------------------------------------------
 *  Find a macro by name
 * ---------------------------------------------------------------- */
static MacroDef *find_macro(const u8 *name, u8 namelen)
{
    int i;
    for (i = 0; i < macro_count; i++) {
        if (macros[i].namelen == namelen &&
            memcmp(macros[i].name, name, namelen) == 0) {
            return &macros[i];
        }
    }
    return NULL;
}

/* ----------------------------------------------------------------
 *  Public: Check if current token is a macro name
 * ---------------------------------------------------------------- */
int macro_is_defined(AsmState *as)
{
    return find_macro(as->idname, as->idlen) != NULL;
}

/* ----------------------------------------------------------------
 *  Collect macro body text until ENDM
 *
 *  Reads lines from as, appending to body buffer.
 *  Handles nested MACRO/ENDM.
 * ---------------------------------------------------------------- */
static char *collect_body(AsmState *as, int *out_len)
{
    int capacity = 1024;
    char *body = (char *)malloc(capacity);
    int len = 0;
    int nest = 1; /* we're inside one MACRO */

    if (!body) {
        fatal_error(as, "Out of memory for macro body");
        return NULL;
    }

    while (nest > 0) {
        if (lex_read_line(as) < 0) {
            err_report(as, 'N', "Unterminated macro");
            break;
        }
        /* Extract the line as a string */
        int line_len = 0;
        while (as->linebuf[line_len] != 0x0D && line_len < LINE_BUF_SIZE - 1)
            line_len++;

        /* Check every whitespace-separated word for MACRO/ENDM keywords.
         * This catches both "label: ENDM" and bare "ENDM". */
        {
            int p = 0;
            int found_nest_change = 0;
            while (p < line_len) {
                /* Skip whitespace */
                while (p < line_len && (as->linebuf[p] == ' ' || as->linebuf[p] == '\t'))
                    p++;
                if (p >= line_len || as->linebuf[p] == ';') break;

                /* Extract word */
                u8 kw[8];
                int kl = 0;
                while (p < line_len && kl < 7 &&
                       as->linebuf[p] != ' ' && as->linebuf[p] != '\t' &&
                       as->linebuf[p] != ':' && as->linebuf[p] != ';') {
                    u8 c = as->linebuf[p];
                    kw[kl] = (c >= 'a' && c <= 'z') ? (c - 0x20) : c;
                    kl++;
                    p++;
                }
                kw[kl] = 0;
                /* Skip colon after label */
                if (p < line_len && as->linebuf[p] == ':') p++;

                /* Check against nesting keywords */
                if (kl == 5 && memcmp(kw, "MACRO", 5) == 0) { nest++; found_nest_change = 1; }
                if (kl == 4 && memcmp(kw, "REPT", 4) == 0)  { nest++; found_nest_change = 1; }
                if (kl == 3 && memcmp(kw, "IRP", 3) == 0)   { nest++; found_nest_change = 1; }
                if (kl == 4 && memcmp(kw, "IRPC", 4) == 0)  { nest++; found_nest_change = 1; }
                if (kl == 4 && memcmp(kw, "ENDM", 4) == 0)  { nest--; found_nest_change = 1; }
                if (kl == 4 && memcmp(kw, "ENDR", 4) == 0)  { nest--; found_nest_change = 1; }

                if (found_nest_change) break; /* don't scan further */
            }

            if (nest <= 0) break; /* don't store the ENDM/ENDR line */
        }

        /* Ensure capacity */
        if (len + line_len + 2 > capacity) {
            capacity *= 2;
            char *nb = (char *)realloc(body, capacity);
            if (!nb) {
                fatal_error(as, "Out of memory for macro body");
                free(body);
                return NULL;
            }
            body = nb;
        }

        /* Append line + newline */
        memcpy(body + len, as->linebuf, line_len);
        len += line_len;
        body[len++] = '\n';
    }

    body[len] = 0;
    *out_len = len;
    return body;
}

/* ----------------------------------------------------------------
 *  MACRO definition: label MACRO [param1, param2, ...]
 * ---------------------------------------------------------------- */
void macro_define(AsmState *as)
{
    if (macro_count >= MAX_MACROS) {
        err_report(as, 'N', "Too many macro definitions");
        /* Skip body */
        int dummy;
        char *body = collect_body(as, &dummy);
        free(body);
        return;
    }

    MacroDef *md = &macros[macro_count];
    memset(md, 0, sizeof(MacroDef));

    /* The macro name is in the label that preceded MACRO keyword.
     * It was already saved by pass_process_line before calling us.
     * We need to get it from the symbol table entry. */

    /* Actually, the name was in idname before the MACRO keyword was parsed.
     * We need to get it from the backup token state.
     * For our implementation, we expect as->bak_idname to hold the macro name. */

    /* Use backup token (the label before MACRO) */
    if (as->label_ptr != 0) {
        u8 *entry = &as->memory[as->label_ptr];
        md->namelen = entry[4];
        memcpy(md->name, &entry[10], md->namelen);
        md->sym_offset = as->label_ptr;
    } else {
        /* No label — use whatever was just read */
        md->namelen = as->bak_idlen;
        memcpy(md->name, as->bak_idname, md->namelen);
    }

    /* Parse parameters: MACRO param1, param2, ... */
    md->nparams = 0;
    int ch = lex_skipspace(as);
    if (ch != 0x0D && ch != ';') {
        lex_pushback(as);
        for (;;) {
            lex_token_copy(as);
            if (as->idlen == 0) break;

            if (md->nparams < MAX_MACRO_PARAMS) {
                MacroParam *mp = &md->params[md->nparams];
                mp->namelen = as->idlen;
                memcpy(mp->name, as->idname, as->idlen);
                md->nparams++;
            }

            ch = lex_skipspace(as);
            if (ch != ',') {
                lex_pushback(as);
                break;
            }
        }
    } else {
        lex_pushback(as);
    }

    /* Collect body until ENDM */
    md->body = collect_body(as, &md->body_len);

    macro_count++;
}

/* ----------------------------------------------------------------
 *  Substitute parameters in a macro body line
 *
 *  Scans line for parameter names (and & concatenation).
 *  Writes substituted text to output buffer.
 * ---------------------------------------------------------------- */
static int substitute_params(const char *line, int line_len,
                             MacroExpansion *exp, char *out, int out_max)
{
    int ip = 0, op = 0;

    while (ip < line_len && op < out_max - 1) {
        char c = line[ip];

        /* Check for & concatenation */
        if (c == '&') {
            ip++;
            continue; /* skip & - it joins tokens */
        }

        /* Check if we're at start of an identifier */
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            c == '_' || c == '?' || c == '.' || c == '$') {
            /* Collect identifier */
            int id_start = ip;
            u8 id_buf[MAX_ID_LEN + 1];
            int id_len = 0;
            while (ip < line_len && id_len < MAX_ID_LEN) {
                char ch = line[ip];
                u8 uch = (ch >= 'a' && ch <= 'z') ? (ch - 0x20) : (u8)ch;
                if ((uch >= 'A' && uch <= 'Z') || (uch >= '0' && uch <= '9') ||
                    uch == '_' || uch == '?' || uch == '.' || uch == '$' || uch == '@') {
                    id_buf[id_len++] = uch;
                    ip++;
                } else {
                    break;
                }
            }

            /* Check if this identifier matches a parameter */
            int found = -1;
            if (exp->def) {
                int j;
                for (j = 0; j < exp->def->nparams; j++) {
                    MacroParam *mp = &exp->def->params[j];
                    if (mp->namelen == (u8)id_len &&
                        memcmp(mp->name, id_buf, id_len) == 0) {
                        found = j;
                        break;
                    }
                }
            }

            /* Check IRP/IRPC parameter */
            if (found < 0 && (exp->is_irp || exp->is_irpc)) {
                if (exp->irp_param_len == (u8)id_len &&
                    memcmp(exp->irp_param, id_buf, id_len) == 0) {
                    found = 0; /* mapped to first arg */
                }
            }

            if (found >= 0 && found < exp->nargs && exp->args[found]) {
                /* Substitute with argument value */
                const char *arg = exp->args[found];
                int alen = (int)strlen(arg);
                if (op + alen < out_max) {
                    memcpy(out + op, arg, alen);
                    op += alen;
                }
            } else {
                /* Not a parameter — copy literally */
                int k;
                for (k = id_start; k < ip && op < out_max - 1; k++) {
                    out[op++] = line[k];
                }
            }
            continue;
        }

        /* Handle LOCAL symbol references: check for ..NNNN patterns */
        /* (LOCAL symbols are pre-substituted when expansion starts) */

        /* Regular character — copy as-is */
        out[op++] = c;
        ip++;
    }

    out[op] = 0;
    return op;
}

/* ----------------------------------------------------------------
 *  Read next line from macro expansion
 *
 *  Returns: 1 if a line was produced, 0 if expansion ended
 * ---------------------------------------------------------------- */
static int macro_read_line(AsmState *as)
{
    if (expansion_depth <= 0) {
        macro_active = 0;
        return 0;
    }

    MacroExpansion *exp = &expansion_stack[expansion_depth - 1];

    for (;;) {
        /* Find next line in body */
        if (!exp->def && !exp->is_rept && !exp->is_irp && !exp->is_irpc) {
            /* Invalid state */
            expansion_depth--;
            macro_active = (expansion_depth > 0);
            return 0;
        }

        const char *body = NULL;
        int body_len = 0;

        if (exp->def) {
            body = exp->def->body;
            body_len = exp->def->body_len;
        } else if (exp->irp_list) {
            body = exp->irp_list;
            body_len = (int)strlen(exp->irp_list);
        }

        if (!body) {
            expansion_depth--;
            macro_active = (expansion_depth > 0);
            return 0;
        }

        /* Check if we've reached end of body */
        if (exp->body_pos >= body_len) {
            /* End of one iteration */
            if (exp->is_rept && exp->repeat_count > 1) {
                /* More repetitions */
                exp->repeat_count--;
                exp->body_pos = 0;
                local_sym_counter++; /* new LOCAL scope */
                continue;
            }

            if (exp->is_irpc) {
                /* Next character */
                exp->irpc_idx++;
                if (exp->irpc_str[exp->irpc_idx] != 0) {
                    exp->body_pos = 0;
                    /* Update arg[0] to next character */
                    char buf[2] = { exp->irpc_str[exp->irpc_idx], 0 };
                    free(exp->args[0]);
                    exp->args[0] = strdup(buf);
                    continue;
                }
            }

            /* Expansion complete */
            /* Free args */
            int j;
            for (j = 0; j < exp->nargs; j++) {
                free(exp->args[j]);
                exp->args[j] = NULL;
            }
            expansion_depth--;
            macro_active = (expansion_depth > 0);
            return 0;
        }

        /* Extract one line (up to \n) */
        int line_start = exp->body_pos;
        int line_end = line_start;
        while (line_end < body_len && body[line_end] != '\n')
            line_end++;
        exp->body_pos = line_end + 1; /* skip the \n */

        int raw_len = line_end - line_start;

        /* Check for EXITM */
        {
            int p = 0;
            while (p < raw_len && (body[line_start + p] == ' ' ||
                                    body[line_start + p] == '\t')) p++;
            u8 kw[8];
            int kl = 0;
            while (p + kl < raw_len && kl < 7 &&
                   body[line_start + p + kl] != ' ' &&
                   body[line_start + p + kl] != '\t') {
                u8 c = (u8)body[line_start + p + kl];
                kw[kl] = (c >= 'a' && c <= 'z') ? (c - 0x20) : c;
                kl++;
            }
            kw[kl] = 0;

            if (kl == 5 && memcmp(kw, "EXITM", 5) == 0) {
                /* Exit this macro */
                int j2;
                for (j2 = 0; j2 < exp->nargs; j2++) {
                    free(exp->args[j2]);
                    exp->args[j2] = NULL;
                }
                expansion_depth--;
                macro_active = (expansion_depth > 0);
                return 0;
            }

            /* Check for LOCAL */
            if (kl == 5 && memcmp(kw, "LOCAL", 5) == 0) {
                /* LOCAL name1, name2, ...
                 * Create local symbol aliases: ..NNNN */
                /* For now, skip LOCAL lines — they don't produce output.
                 * The local symbols are created in the symbol table. */
                /* Parse local names and create aliases */
                int lp = p + kl;
                while (lp < raw_len) {
                    while (lp < raw_len && (body[line_start + lp] == ' ' ||
                                             body[line_start + lp] == '\t' ||
                                             body[line_start + lp] == ','))
                        lp++;
                    if (lp >= raw_len) break;

                    /* Read identifier */
                    u8 local_name[MAX_ID_LEN + 1];
                    int ln_len = 0;
                    while (lp < raw_len && ln_len < MAX_ID_LEN) {
                        u8 ch = (u8)body[line_start + lp];
                        if ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') ||
                            (ch >= '0' && ch <= '9') || ch == '_' || ch == '?') {
                            local_name[ln_len++] = (ch >= 'a' && ch <= 'z') ?
                                                   (ch - 0x20) : ch;
                            lp++;
                        } else {
                            break;
                        }
                    }

                    if (ln_len > 0) {
                        /* Create a generated symbol name ..NNNN */
                        local_sym_counter++;
                        char gen_name[MAX_ID_LEN + 1];
                        snprintf(gen_name, sizeof(gen_name), "..%04X",
                                 local_sym_counter);

                        /* Add as extra parameter substitution:
                         * local_name → gen_name */
                        if (exp->nargs < MAX_MACRO_PARAMS && exp->def) {
                            MacroParam *mp = &exp->def->params[exp->def->nparams];
                            if (exp->def->nparams < MAX_MACRO_PARAMS) {
                                mp->namelen = (u8)ln_len;
                                memcpy(mp->name, local_name, ln_len);
                                exp->def->nparams++;
                                exp->args[exp->nargs] = strdup(gen_name);
                                exp->nargs++;
                            }
                        }

                        /* Create symbol in symbol table */
                        u8 saved_idlen = as->idlen;
                        u8 saved_idname[MAX_ID_LEN + 2];
                        memcpy(saved_idname, as->idname, MAX_ID_LEN + 2);

                        int gl = (int)strlen(gen_name);
                        as->idlen = (u8)gl;
                        memcpy(as->idname, gen_name, gl);
                        if (!sym_search_user(as)) {
                            sym_add_entry(as, 0);
                        }

                        as->idlen = saved_idlen;
                        memcpy(as->idname, saved_idname, MAX_ID_LEN + 2);
                    }
                }
                continue; /* skip this line, read next */
            }
        }

        /* Perform parameter substitution */
        int out_len = substitute_params(body + line_start, raw_len,
                                        exp, macro_line_buf,
                                        LINE_BUF_SIZE - 2);

        /* Copy to as->linebuf for processing */
        memcpy(as->linebuf, macro_line_buf, out_len);
        as->linebuf[out_len] = 0x0D; /* CR terminator */
        as->line_pos = 0;

        (void)out_len;
        return 1;
    }
}

/* ----------------------------------------------------------------
 *  Start macro expansion
 * ---------------------------------------------------------------- */
void macro_expand(AsmState *as)
{
    MacroDef *md = find_macro(as->idname, as->idlen);
    if (!md) {
        err_report(as, 'O', "Undefined macro");
        return;
    }

    if (expansion_depth >= MAX_MACRO_NEST) {
        err_report(as, 'N', "Macro nesting too deep");
        return;
    }

    MacroExpansion *exp = &expansion_stack[expansion_depth];
    memset(exp, 0, sizeof(MacroExpansion));
    exp->def = md;
    exp->body_pos = 0;
    exp->repeat_count = 1;
    exp->local_base = local_sym_counter;

    /* Parse arguments from the call line */
    exp->nargs = 0;
    int ch = lex_skipspace(as);

    if (ch != 0x0D && ch != ';') {
        lex_pushback(as);

        int pi = 0;
        while (pi < md->nparams) {
            ch = lex_skipspace(as);
            if (ch == 0x0D || ch == ';') {
                lex_pushback(as);
                break;
            }

            /* Collect argument value (up to comma or EOL) */
            char arg_buf[256];
            int arg_len = 0;

            if (ch == '<') {
                /* Angle-bracket delimited: <value> */
                int angle_depth = 1;
                for (;;) {
                    ch = lex_nextchar(as);
                    if (ch == 0x0D) break;
                    if (ch == '<') angle_depth++;
                    if (ch == '>') {
                        angle_depth--;
                        if (angle_depth <= 0) break;
                    }
                    if (arg_len < 255) arg_buf[arg_len++] = (char)ch;
                }
            } else {
                lex_pushback(as);
                for (;;) {
                    ch = lex_nextchar(as);
                    if (ch == 0x0D || ch == ',' || ch == ';') {
                        if (ch == ',') { /* consumed */ }
                        else lex_pushback(as);
                        break;
                    }
                    if (arg_len < 255) arg_buf[arg_len++] = (char)ch;
                }
                /* Trim trailing spaces */
                while (arg_len > 0 && (arg_buf[arg_len-1] == ' ' ||
                       arg_buf[arg_len-1] == '\t'))
                    arg_len--;
            }

            arg_buf[arg_len] = 0;
            exp->args[pi] = strdup(arg_buf);
            exp->nargs = pi + 1;
            pi++;

            /* Check for comma separator */
            if (ch != ',') {
                ch = lex_skipspace(as);
                if (ch == ',') continue;
                lex_pushback(as);
                break;
            }
        }
    } else {
        lex_pushback(as);
    }

    /* Fill missing args with empty strings */
    while (exp->nargs < md->nparams) {
        exp->args[exp->nargs] = strdup("");
        exp->nargs++;
    }

    expansion_depth++;
    macro_active = 1;
}

/* ----------------------------------------------------------------
 *  REPT directive: REPT count ... ENDM
 * ---------------------------------------------------------------- */
void macro_rept(AsmState *as)
{
    u16 count = expr_eval_simple(as);

    if (expansion_depth >= MAX_MACRO_NEST) {
        err_report(as, 'N', "Macro nesting too deep");
        /* Skip body */
        int dummy;
        char *body = collect_body(as, &dummy);
        free(body);
        return;
    }

    /* Collect body */
    int body_len;
    char *body = collect_body(as, &body_len);

    if (count == 0) {
        free(body);
        return;
    }

    /* Create a temporary MacroDef for the body */
    MacroExpansion *exp = &expansion_stack[expansion_depth];
    memset(exp, 0, sizeof(MacroExpansion));

    /* We don't use a MacroDef for REPT — store body directly */
    /* Abuse irp_list to store the body text */
    exp->irp_list = body; /* will be freed when expansion ends */
    exp->def = NULL;
    exp->body_pos = 0;
    exp->repeat_count = count;
    exp->repeat_total = count;
    exp->is_rept = 1;
    exp->local_base = local_sym_counter;

    expansion_depth++;
    macro_active = 1;
}

/* ----------------------------------------------------------------
 *  IRP directive: IRP param, <val1, val2, ...> ... ENDM
 * ---------------------------------------------------------------- */
void macro_irp(AsmState *as)
{
    /* Read parameter name */
    lex_token_copy(as);
    u8 param_name[MAX_ID_LEN + 1];
    u8 param_len = as->idlen;
    memcpy(param_name, as->idname, param_len);

    /* Expect comma */
    int ch = lex_skipspace(as);
    if (ch != ',') {
        err_syntax(as);
        lex_pushback(as);
    }

    /* Read value list (angle-bracket delimited) */
    ch = lex_skipspace(as);

    /* Collect values */
    char values[MAX_MACRO_BODY];
    int nvals = 0;
    char *val_ptrs[256];
    int val_count = 0;

    if (ch == '<') {
        int vp = 0;
        int angle = 1;
        for (;;) {
            ch = lex_nextchar(as);
            if (ch == 0x0D) break;
            if (ch == '<') angle++;
            if (ch == '>') { angle--; if (angle <= 0) break; }
            if (vp < MAX_MACRO_BODY - 1) values[vp++] = (char)ch;
        }
        values[vp] = 0;
        nvals = vp;

        /* Split by commas */
        char *p = values;
        while (*p) {
            while (*p == ' ' || *p == '\t') p++;
            val_ptrs[val_count] = p;
            while (*p && *p != ',') p++;
            if (*p == ',') { *p = 0; p++; }
            /* Trim trailing spaces */
            char *e = val_ptrs[val_count] + strlen(val_ptrs[val_count]) - 1;
            while (e >= val_ptrs[val_count] && (*e == ' ' || *e == '\t')) *e-- = 0;
            val_count++;
            if (val_count >= 256) break;
        }
    } else {
        lex_pushback(as);
        err_syntax(as);
    }

    if (expansion_depth >= MAX_MACRO_NEST) {
        err_report(as, 'N', "Macro nesting too deep");
        int dummy;
        free(collect_body(as, &dummy));
        return;
    }

    /* Collect body */
    int body_len;
    char *body = collect_body(as, &body_len);

    if (val_count == 0) {
        free(body);
        return;
    }

    /* For each value, we expand the body once.
     * We store all values and iterate. */
    MacroExpansion *exp = &expansion_stack[expansion_depth];
    memset(exp, 0, sizeof(MacroExpansion));
    exp->irp_list = body;
    exp->def = NULL;
    exp->body_pos = 0;
    exp->repeat_count = val_count;
    exp->repeat_total = val_count;
    exp->is_irp = 1;
    exp->irp_param_len = param_len;
    memcpy(exp->irp_param, param_name, param_len);

    /* Set first arg */
    exp->args[0] = strdup(val_ptrs[0]);
    exp->nargs = 1;

    /* Store remaining values for later iterations */
    /* We'll handle iteration in macro_read_line */
    /* For now, simple approach: repeat_count holds remaining values */
    /* We need to store all value strings */
    /* Store them in a semicolon-separated format in irpc_str */
    {
        int total = 0;
        int i;
        for (i = 0; i < val_count && total < 255; i++) {
            int vl = (int)strlen(val_ptrs[i]);
            if (i > 0) exp->irpc_str[total++] = ';';
            memcpy(exp->irpc_str + total, val_ptrs[i], vl);
            total += vl;
        }
        exp->irpc_str[total] = 0;
        exp->irpc_idx = 0;
    }

    expansion_depth++;
    macro_active = 1;
    (void)nvals;
}

/* ----------------------------------------------------------------
 *  IRPC directive: IRPC param, string ... ENDM
 * ---------------------------------------------------------------- */
void macro_irpc(AsmState *as)
{
    /* Read parameter name */
    lex_token_copy(as);
    u8 param_name[MAX_ID_LEN + 1];
    u8 param_len = as->idlen;
    memcpy(param_name, as->idname, param_len);

    /* Expect comma */
    int ch = lex_skipspace(as);
    if (ch != ',') {
        err_syntax(as);
        lex_pushback(as);
    }

    /* Read string */
    char str[256];
    int slen = 0;
    ch = lex_skipspace(as);
    if (ch == '<') {
        for (;;) {
            ch = lex_nextchar(as);
            if (ch == '>' || ch == 0x0D) break;
            if (slen < 255) str[slen++] = (char)ch;
        }
    } else {
        lex_pushback(as);
        for (;;) {
            ch = lex_nextchar(as);
            if (ch == 0x0D || ch == ';' || ch == ' ' || ch == '\t') {
                lex_pushback(as);
                break;
            }
            if (slen < 255) str[slen++] = (char)ch;
        }
    }
    str[slen] = 0;

    if (expansion_depth >= MAX_MACRO_NEST) {
        err_report(as, 'N', "Macro nesting too deep");
        int dummy;
        free(collect_body(as, &dummy));
        return;
    }

    int body_len;
    char *body = collect_body(as, &body_len);

    if (slen == 0) {
        free(body);
        return;
    }

    MacroExpansion *exp = &expansion_stack[expansion_depth];
    memset(exp, 0, sizeof(MacroExpansion));
    exp->irp_list = body;
    exp->def = NULL;
    exp->body_pos = 0;
    exp->is_irpc = 1;
    memcpy(exp->irpc_str, str, slen + 1);
    exp->irpc_idx = 0;
    exp->irp_param_len = param_len;
    memcpy(exp->irp_param, param_name, param_len);

    /* Set first char as argument */
    char buf[2] = { str[0], 0 };
    exp->args[0] = strdup(buf);
    exp->nargs = 1;

    expansion_depth++;
    macro_active = 1;
}

/* ----------------------------------------------------------------
 *  EXITM — handled inside macro_read_line
 * ---------------------------------------------------------------- */
void macro_exitm(AsmState *as)
{
    if (expansion_depth <= 0) {
        err_report(as, 'N', "EXITM outside macro");
        return;
    }
    /* This is called if EXITM appears as a directive outside body reading.
     * Shouldn't normally happen, as EXITM is detected in macro_read_line. */
    (void)as;
}

/* ----------------------------------------------------------------
 *  PUBLIC API: Read next line (from macro or from file)
 *
 *  Returns 1 if line came from macro, 0 if from file.
 *  When returning 1, linebuf is already filled.
 * ---------------------------------------------------------------- */
int macro_get_line(AsmState *as)
{
    if (!macro_active || expansion_depth <= 0) return 0;
    return macro_read_line(as);
}

/* ----------------------------------------------------------------
 *  PUBLIC API: Check if we're inside a macro expansion
 * ---------------------------------------------------------------- */
int macro_is_active(void)
{
    return macro_active && expansion_depth > 0;
}

/* ----------------------------------------------------------------
 *  PUBLIC API: Reset macro state (between passes)
 * ---------------------------------------------------------------- */
void macro_reset(void)
{
    expansion_depth = 0;
    macro_active = 0;
    macro_line_len = 0;
    macro_line_pos = 0;
    /* Don't reset macro_count — definitions persist across passes */
    /* Don't reset local_sym_counter — must continue from pass 1 */
}

/* ----------------------------------------------------------------
 *  PUBLIC API: Initialize macro system
 * ---------------------------------------------------------------- */
void macro_init(void)
{
    macro_count = 0;
    expansion_depth = 0;
    macro_active = 0;
    local_sym_counter = 0;
}
