/**

	File:			dcpuops.c

	Project:		DCPU-16 Tools
	Component:		Emulator

	Authors:		James Rhodes
					Aaron Miller

	Description:	Handles opcode instructions in the
					virtual machine.

**/

#define PRIVATE_VM_ACCESS

#include "dcpubase.h"
#include "dcpuops.h"
#include "dcpuhook.h"

#define VM_CHECK_ARITHMETIC_FLOW(op, val_a, val_b) \
	if ((int32_t)val_a op (int32_t)val_b < (int32_t)0) \
		vm->ex = AR_UNDERFLOW; \
	else if ((int32_t)val_a op (int32_t)val_b > (int32_t)AR_MAX) \
		vm->ex = AR_OVERFLOW; \
	else \
		vm->ex = AR_NOFLOW;

#define VM_SKIP_RESET if(vm->skip) {vm->skip = false; return;}

#define VM_HOOK_FIRE(var) \
	if (var >= (uint16_t*)&vm->ram && var < (uint16_t*)&vm->ram + 0x10000) \
		vm_hook_fire(vm, (uint16_t)(var - (uint16_t*)&vm->ram), HOOK_ON_WRITE);

uint16_t* vm_internal_get_store(vm_t* vm, uint16_t loc)
{
	// Don't modify the state of the program if
	// we're skipping.
	if (vm->skip)
	{
		if((loc >= NXT_VAL_A && loc <= NXT_VAL_J) || loc == NXT)
			vm_consume_word(vm);
		return &vm->dummy;
	}

	// Otherwise, run normally.
	if (loc >= REG_A && loc <= REG_J)
		return &vm->registers[loc];
	else if (loc >= VAL_A && loc <= VAL_J)
		return &vm->ram[(uint16_t)vm->registers[loc - VAL_A]];
	else if (loc >= NXT_VAL_A && loc <= NXT_VAL_J)
		return &vm->ram[(uint16_t)(vm->registers[loc - NXT_VAL_A] + vm_consume_word(vm))];
	else if (loc == POP)
	{
		uint16_t t = vm->sp++;
		return &vm->ram[t];
	}
	else if (loc == PEEK)
	{
		uint16_t t = vm->sp;
		return &vm->ram[t];
	}
	else if (loc == PUSH)
	{
		uint16_t t = --vm->sp;
		return &vm->ram[t];
	}
	else if (loc == IA)
		return &vm->ia;
	else if (loc == SP)
		return &vm->sp;
	else if (loc == PC)
		return &vm->pc;
	else if (loc == EX)
		return &vm->ex;
	else if (loc == NXT)
		return &vm->ram[(uint16_t)vm_consume_word(vm)];
	else
		return &vm->dummy; // Dummy position for assignments that silently fail.
}

// Sometimes an instruction will get the value of 'a' for a second
// time (such as in the case of ADD).  We need to make sure that
// if the value of 'a' modified the VM state in vm_internal_get_store
// that we don't modify the state again (for example, not incrementing
// PC for NXT).
uint16_t vm_resolve_value_once(vm_t* vm, uint16_t val)
{
	switch (val)
	{
	case NXT:
		return vm->ram[(uint16_t)vm->ram[(uint16_t)(vm->pc - 1)]];
	case POP:
	case PUSH:
		return vm->ram[(uint16_t)vm->sp];
	case NXT_VAL_A:
	case NXT_VAL_B:
	case NXT_VAL_C:
	case NXT_VAL_X:
	case NXT_VAL_Y:
	case NXT_VAL_Z:
	case NXT_VAL_I:
	case NXT_VAL_J:
		return vm->ram[(uint16_t)(vm->registers[val - NXT_VAL_A] + vm->ram[(uint16_t)(vm->pc - 1)])];
	default:
		return vm_resolve_value(vm, val);
	}
}

void vm_op_set(vm_t* vm, uint16_t b, uint16_t a)
{
	uint16_t val_a;
	uint16_t* store_b = vm_internal_get_store(vm, b);
	val_a = vm_resolve_value(vm, a);
	*store_b = val_a;
	VM_HOOK_FIRE(store_b);
	vm->skip = false;
}

void vm_op_add(vm_t* vm, uint16_t b, uint16_t a)
{
	uint16_t val_b, val_a;
	uint16_t* store_b = vm_internal_get_store(vm, b);
	val_b = vm_resolve_value_once(vm, b);
	val_a = vm_resolve_value(vm, a);
	VM_SKIP_RESET;
	*store_b = val_b + val_a;
	VM_CHECK_ARITHMETIC_FLOW(+, val_b, val_a);
	VM_HOOK_FIRE(store_b);
}

void vm_op_sub(vm_t* vm, uint16_t b, uint16_t a)
{
	uint16_t val_b, val_a;
	uint16_t* store_b = vm_internal_get_store(vm, b);
	val_b = vm_resolve_value_once(vm, b);
	val_a = vm_resolve_value(vm, a);
	VM_SKIP_RESET;
	*store_b = val_b - val_a;
	VM_CHECK_ARITHMETIC_FLOW(-, val_b, val_a);
	VM_HOOK_FIRE(store_b);
}

void vm_op_mul(vm_t* vm, uint16_t b, uint16_t a)
{
	uint16_t val_b, val_a;
	uint16_t* store_b = vm_internal_get_store(vm, b);
	val_b = vm_resolve_value_once(vm, b);
	val_a = vm_resolve_value(vm, a);
	VM_SKIP_RESET;
	*store_b = val_b * val_a;
	vm->ex = ((val_b * val_a) >> 16) & 0xffff;
	VM_HOOK_FIRE(store_b);
}

void vm_op_div(vm_t* vm, uint16_t b, uint16_t a)
{
	uint16_t val_b, val_a;
	uint16_t* store_b = vm_internal_get_store(vm, b);
	val_b = vm_resolve_value_once(vm, b);
	val_a = vm_resolve_value(vm, a);
	VM_SKIP_RESET;
	if (val_a != 0)
	{
		*store_b = val_b / val_a;
		vm->ex = ((val_b << 16) / val_a) & 0xffff;
	}
	else
	{
		*store_b = 0;
		vm->ex = 0;
	}
	VM_HOOK_FIRE(store_b);
}

void vm_op_mod(vm_t* vm, uint16_t b, uint16_t a)
{
	uint16_t val_b, val_a;
	uint16_t* store_b = vm_internal_get_store(vm, b);
	val_b = vm_resolve_value_once(vm, b);
	val_a = vm_resolve_value(vm, a);
	VM_SKIP_RESET;
	if (val_a != 0)
		*store_b = val_b % val_a;
	else
		*store_b = 0;
	VM_HOOK_FIRE(store_b);
}

void vm_op_shl(vm_t* vm, uint16_t b, uint16_t a)
{
	uint16_t val_b, val_a;
	uint16_t* store_b = vm_internal_get_store(vm, b);
	val_b = vm_resolve_value_once(vm, b);
	val_a = vm_resolve_value(vm, a);
	VM_SKIP_RESET;
	*store_b = val_b << val_a;
	vm->ex = ((val_b << val_a) >> 16) & 0xffff;
	VM_HOOK_FIRE(store_b);
}

void vm_op_shr(vm_t* vm, uint16_t a, uint16_t b)
{
	uint16_t val_b, val_a;
	uint16_t* store_b = vm_internal_get_store(vm, b);
	val_b = vm_resolve_value_once(vm, b);
	val_a = vm_resolve_value(vm, a);
	VM_SKIP_RESET;
	*store_b = val_b >> val_a;
	vm->ex = ((val_b << 16) >> val_a) & 0xffff;
	VM_HOOK_FIRE(store_b);
}

void vm_op_and(vm_t* vm, uint16_t b, uint16_t a)
{
	uint16_t val_b, val_a;
	uint16_t* store_b = vm_internal_get_store(vm, b);
	val_b = vm_resolve_value_once(vm, b);
	val_a = vm_resolve_value(vm, a);
	VM_SKIP_RESET;
	*store_b = val_b & val_a;
	VM_HOOK_FIRE(store_b);
}

void vm_op_bor(vm_t* vm, uint16_t b, uint16_t a)
{
	uint16_t val_b, val_a;
	uint16_t* store_b = vm_internal_get_store(vm, b);
	val_b = vm_resolve_value_once(vm, b);
	val_a = vm_resolve_value(vm, a);
	VM_SKIP_RESET;
	*store_b = val_b | val_a;
	VM_HOOK_FIRE(store_b);
}

void vm_op_xor(vm_t* vm, uint16_t b, uint16_t a)
{
	uint16_t val_b, val_a;
	uint16_t* store_b = vm_internal_get_store(vm, b);
	val_b = vm_resolve_value_once(vm, b);
	val_a = vm_resolve_value(vm, a);
	VM_SKIP_RESET;
	*store_b = val_b ^ val_a;
	VM_HOOK_FIRE(store_b);
}

void vm_op_ife(vm_t* vm, uint16_t b, uint16_t a)
{
	uint16_t val_b, val_a;
	val_b = vm_resolve_value(vm, b);
	val_a = vm_resolve_value(vm, a);
	VM_SKIP_RESET;
	vm->skip = !(val_b == val_a);
}

void vm_op_ifn(vm_t* vm, uint16_t b, uint16_t a)
{
	uint16_t val_b, val_a;
	val_b = vm_resolve_value(vm, b);
	val_a = vm_resolve_value(vm, a);
	VM_SKIP_RESET;
	vm->skip = !(val_b != val_a);
}

void vm_op_ifg(vm_t* vm, uint16_t b, uint16_t a)
{
	uint16_t val_b, val_a;
	val_b = vm_resolve_value(vm, b);
	val_a = vm_resolve_value(vm, a);
	VM_SKIP_RESET;
	vm->skip = !(val_b > val_a);
}

void vm_op_ifb(vm_t* vm, uint16_t b, uint16_t a)
{
	uint16_t val_b, val_a;
	val_b = vm_resolve_value(vm, b);
	val_a = vm_resolve_value(vm, a);
	VM_SKIP_RESET;
	vm->skip = !((val_b & val_a) != 0);
}

void vm_op_jsr(vm_t* vm, uint16_t a)
{
	uint16_t new_pc = vm_resolve_value(vm, a);
	uint16_t t;
	VM_SKIP_RESET;
	t = --vm->sp;
	vm->ram[t] = vm->pc;
	vm->pc = new_pc;
}

void vm_op_int(vm_t* vm, uint16_t a)
{
	vm_interrupt(vm, a);
}

void vm_op_ing(vm_t* vm, uint16_t a)
{
	vm_op_set(vm, a, IA);
}

void vm_op_ins(vm_t* vm, uint16_t a)
{
	vm_op_set(vm, IA, a);
}

void vm_op_hwn(vm_t* vm, uint16_t a)
{
	uint16_t* store_a = vm_internal_get_store(vm, a);
	*store_a = 0 /* no hardware connected */;
	VM_HOOK_FIRE(store_a);
	vm->skip = false;
}

void vm_op_hwq(vm_t* vm, uint16_t a)
{
	uint16_t* store_a = vm_internal_get_store(vm, REG_A);
	uint16_t* store_b = vm_internal_get_store(vm, REG_B);
	uint16_t* store_c = vm_internal_get_store(vm, REG_C);
	uint16_t* store_x = vm_internal_get_store(vm, REG_X);
	uint16_t* store_y = vm_internal_get_store(vm, REG_Y);

	/* there are no hardware devices connected, so zero out */
	*store_a = 0;
	*store_b = 0;
	*store_c = 0;
	*store_x = 0;
	*store_y = 0;

	VM_HOOK_FIRE(store_a);
	VM_HOOK_FIRE(store_b);
	VM_HOOK_FIRE(store_c);
	VM_HOOK_FIRE(store_x);
	VM_HOOK_FIRE(store_y);
	vm->skip = false;
}

void vm_op_hwi(vm_t* vm, uint16_t a)
{
	// Interrupts are not sent to hardware yet (as there
	// is no hardware defined).
}