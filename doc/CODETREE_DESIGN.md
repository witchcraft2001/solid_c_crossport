# CC2 Code Tree Architecture Design

## Goal
Replace flat VStack evaluator with tree-based architecture to match
original CCC.ASM optimizer behavior. Target: byte-identical output.

## Original CCC.ASM Architecture (from reverse-engineering)

### Memory Layout
```
High memory (D9D02):
  ↓ Code tree nodes (21 bytes each, grow DOWN from D9CFC)
  ↓
  --- D9CF6 = boundary ---
  ↑
  ↑ Symbol table entries (6 bytes each, grow UP from Table)
Low memory (Table):
```

### Processing Flow
```
A1274 loop:
  A1048 → parse one statement
    A314F → build expression tree (calls A13CA to allocate nodes)
    A19FB → process expression tree (NOT code emission - tree manipulation)
  repeat until "}"

A3A5B → Optimizer Phase 1
  - Build optimizer entries (24 bytes each)
  - Walk code tree, count variable usage
  - Determine scope chains, nesting depth
  - Local-to-global promotion decisions

A6131 → Optimizer Phase 2
  - Register allocation (T9BD5 table, 16 vars)
  - Assign BC/DE/HL based on usage counts
  - Code emission with templates

A6225 → Template output engine
  - Format codes: R(reg), P(pair), D(decimal), S(string), M(memory)
```

## Our Architecture

### Phase 1: Parse TMC → Tree Nodes

```c
/* Tree node - represents one TMC operation */
typedef struct {
    u8  op;          /* TMC operator: +, -, *, /, :, etc. */
    u8  type;        /* result type: C, N, I, R */
    u16 value;       /* immediate value, var id, label num */
    char sym[32];    /* symbol name for globals */
    int left;        /* index of left child (-1 if none) */
    int right;       /* index of right child (-1 if none) */
    int parent;      /* parent node index */
    int next;        /* next statement in sequence */

    /* Analysis fields (filled by Phase 2) */
    int depth;       /* loop nesting depth */
    int var_id;      /* variable id if this is a var ref */
    u8  flags;       /* is_addr, is_lvalue, etc. */
} TreeNode;

#define MAX_TREE_NODES 4096
static TreeNode tree_nodes[MAX_TREE_NODES];
static int tree_node_count;
```

### Phase 2: Analyze Tree

For each function body:
1. Walk all statements, count variable references
2. Track loop depth for each reference
3. Identify variables used across function calls
4. Score variables for register allocation:
   - score = count * (1 + depth)  (loop vars score higher)
   - penalize vars used across calls (need save/restore)

### Phase 3: Register Allocation

```c
typedef struct {
    int var_id;
    int score;
    int reg;         /* VK_BC, VK_DE, VK_HL, or VK_NONE */
    int is_param;
    int crosses_call; /* needs push/pop save */
} RegCandidate;
```

Allocation strategy (matching CCC.ASM behavior):
- Highest-scored non-param var → DE (loop counter)
- Second highest → BC (array base)
- Params that cross calls → push/pop save
- Pointer vars used in many iterations → promote to dseg global

### Phase 4: Code Emission from Tree

Walk tree in execution order, emit Z80 using templates.
Key templates (from A6225):
- Load var: "ld\thl,(M)" or "ld\tl,(ix+D)"
- Store var: "ld\t(M),hl"
- Add: "add\thl,P"
- etc.

## Migration Plan

### Step 1: Tree Building (parallel, non-destructive)
- Add tree builder that runs alongside existing gen_expr_stmt
- Verify tree captures all TMC operations correctly
- No code generation changes

### Step 2: Enhanced Variable Analysis
- Replace text-based body_count_usage() with tree walk
- Feed better counts into existing try_register_allocate()
- Small diff improvements expected

### Step 3: BC Register Support
- Extend try_register_allocate() to assign BC
- Requires adding VK_BC paths throughout gen_expr_stmt
- Major diff improvement (224 missing add hl,bc)

### Step 4: Tree-Based Emission
- Replace gen_expr_stmt with tree walker
- Emit using same emit_instr infrastructure
- Instruction ordering matches original
- Biggest impact but highest risk
