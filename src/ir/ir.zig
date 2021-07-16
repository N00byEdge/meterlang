pub const InstrType = enum {
    ref_next_instruction,

    add_stack,
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
    ref_next_instruction: struct {
        id: usize,
    },

    add_stack: struct {
        size: usize,
    },
    drop_stack: void,

    load_constant: i65,
    compare_constant: i65,
    add_constant: i65,

    adress_stack_var: StackVarRef,
    load_stack_var: struct {
        sign_extend: bool,
        stack_op: StackVarOp,
    },
    store_stack_var: StackVarOp,

    compare_stack_var: StackVarOp,
    bitxor_stack_var: StackVarOp,
    bitor_stack_var: StackVarOp,
    bitand_stack_var: StackVarOp,

    jump: Jump,

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
