/**

	File:		NCharacter.cpp

	Project:	DCPU-16 Tools
	Component:	LibDCPU-ci-lang-c

	Authors:	James Rhodes

	Description:	Defines the NCharacter AST class.

**/

#include <AsmGenerator.h>
#include <CompilerException.h>
#include "NCharacter.h"
#include "NInteger.h"

AsmBlock* NCharacter::compile(AsmGenerator& context)
{
	AsmBlock* block = new AsmBlock();

	// Load the numeric value in register A.
	*block << "	SET A, " << (uint8_t)((char)this->value[0]) << "" << std::endl;

	return block;
}

AsmBlock* NCharacter::reference(AsmGenerator& context)
{
	throw new CompilerException("Unable to get reference to a character node.");
}

IType& NCharacter::getExpressionType(AsmGenerator& context)
{
	// A character has the type char.
	return NInteger::CharType;
}
