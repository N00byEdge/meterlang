pub const InstrType = enum {
    ref_next_instruction,

    add_stack,
    store_arguments,
    drop_stack,

    load_constant,
    compare_constant,
    add_constant,

    adress_stack_var,
    load_stack_var,
    store_stack_var,

    compare_stack_var,
    bitxor_stack_var,
    bitor_stack_var,
    bitand_stack_var,

    jump,

    adress_xref,
    load_xref,
    store_xref,

    ptr_store_constant,
    ptr_store,
    ptr_load,
};

pub const Instruction = union(InstrType) {
    // Creates a reference to the next instruction using the specified id
    ref_next_instruction: usize,

    // Creates a new stack slot with <value> bytes of stack space.
    add_stack: usize,

    // Stores the first <value> arguments onto the stack. Creates a new stack
    // slot (like using .add_stack), and you can access the arguments using offsetting
    store_arguments: usize,

    // Drops the top stack slot
    drop_stack: void,

    // Loads a constant value into the accumulator
    load_constant: i65,

    // Compares the accumulator to a constant
    compare_constant: i65,

    // Adds a constant to the accumulator
    add_constant: i65,

    // Puts the address of a stack variable into the accumulator
    adress_stack_var: StackVarRef,

    // Loads a stack variable into the accumulator
    load_stack_var: struct {
        sign_extend: bool,
        stack_op: StackVarOp,
    },

    // Stores the accumulator value to a stack variable
    store_stack_var: StackVarOp,

    // Compare the accumulator to a stack variable
    compare_stack_var: StackVarOp,

    // Applies accumulator = accumulator ^ stack_var
    bitxor_stack_var: StackVarOp,

    // Applies accumulator = accumulator | stack_var
    bitor_stack_var: StackVarOp,

    // Applies accumulator = accumulator & stack_var
    bitand_stack_var: StackVarOp,

    // (Optionally conditionally) jumps to a referenced instruction.
    // If using a cmp conditional, it's affected by the precious compare
    // instruction.
    jump: Jump,

    // Loads the address of an xref into the accumulator
    adress_xref: Xref,

    // Load accumulator from xref
    load_xref: struct {
        sign_extend: bool,
        extref: Xref,
        bit_size: u7,
    },

    // Store accumulator at the xref
    store_xref: struct {
        extref: Xref,
        bit_size: u7,
    },

    // Store `value` to pointer in accumulator
    ptr_store_constant: struct {
        bit_size: u7,
        value: i65,
        store_offset: usize,
    },

    // Store accumulator at where the pointer at `ptr_loc` points.
    ptr_store: struct {
        bit_size: u7,
        ptr_loc: StackVarRef,
        store_offset: usize,
    },

    // Load accumulator from where the pointer at `ptr_loc` points.
    ptr_load: struct {
        sign_extend: bool,
        bit_size: u7,
        ptr_loc: StackVarRef,
        load_offset: usize,
    },
};

pub const Xref = struct {
    id: usize,
};

pub const StackVarRef = struct {
    idx: usize,
    offset: usize,
};

pub const StackVarOp = struct {
    stack_var: StackVarRef,
    bit_size: u7,
};

pub const Jump = struct {
    pub const Condition = enum {
        Always,

        AccEqualZero,
        AccNotEqualZero,
        AccPositive,
        AccNegative,

        CmpEqual,
        CmpNotEqual,

        CmpAccLessThanOrEqualSigned,
        CmpAccGreaterThanOrEqualSigned,

        CmpAccLessThanOrEqualUnsigned,
        CmpAccGreaterThanOrEqualUnsigned,

        CmpAccLessThanSigned,
        CmpAccGreaterThanSigned,

        CmpAccLessThanUnsigned,
        CmpAccGreaterThanUnsigned,
    };

    id: usize,
    condition: Condition,
};
