/// The types that a value can take on
pub const ValueType = union(TypeKind) {
	memory_layout: MemoryLayout,
	struct_layout: StructLayout,

	integral: IntegralType,
	pointer: PointerType,
};

pub const TypeKind = enum {
	memory_layout,
	stuct_layout,

	integral,
	pointer,
};

/// A pointer type, knows what type it points to
pub const PointerType = struct {
	pointed_type: *ValueType,
	allow_null: bool,
};

/// Your basic integral type
pub const IntegralType = struct {
	bit_size: usize,
	signed: bool,
};

/// When you want to explicitly specify the memory layout for ABI boundaries, mmio regions etc.
pub const MemoryLayout = struct {
	byte_size: usize,

	registers: []RegisterLayout,
	values: []ValueLayout,
};

/// Your typical struct layout type.
/// You don't specify the layout, the compiler comes up with one.
pub const StructLayout = struct {
	values: []ValueLayout,
};

/// Specifies an mmio register location and the bitfields it has.
pub const RegisterLayout = struct {
	name: []const u8,
	size: usize,
	offset: usize,
	integral_value_type: ?IntegralType,
	bitfields: []RegisterBitfield,
};

/// Specifies a value within a register
pub const RegisterBitfield = struct {
	name: []const u8,
	bit_offset: usize,
	integral_value_type: IntegralType,
};

/// Specififies a single traditional struct member
pub const ValueLayout = struct {
	name: []const u8,
	value_type: *ValueType,
	byte_offset: usize,
	bit_offset: usize,
};
