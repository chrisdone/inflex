{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

-- | Derived class instances for shared types.

module Inflex.Instances where

import Inflex.Types

--------------------------------------------------------------------------------
-- AST types

deriving instance Show (Expression Parsed)
deriving instance Eq (Expression Parsed)
deriving instance Ord (Expression Parsed)
deriving instance Show (Expression Renamed)
deriving instance Eq (Expression Renamed)
deriving instance Ord (Expression Renamed)
deriving instance Eq (Expression Generated)
deriving instance Ord (Expression Generated)
deriving instance Show (Expression Generated)
deriving instance Eq (Expression Solved)
deriving instance Ord (Expression Solved)
deriving instance Show (Expression Solved)
deriving instance Eq (Expression Generalised)
deriving instance Ord (Expression Generalised)
deriving instance Show (Expression Generalised)
deriving instance Eq (Expression Resolved)
deriving instance Ord (Expression Resolved)
deriving instance Show (Expression Resolved)

deriving instance Show (Record Parsed)
deriving instance Eq (Record Parsed)
deriving instance Ord (Record Parsed)
deriving instance Show (Record Renamed)
deriving instance Eq (Record Renamed)
deriving instance Ord (Record Renamed)
deriving instance Eq (Record Generated)
deriving instance Ord (Record Generated)
deriving instance Show (Record Generated)
deriving instance Eq (Record Solved)
deriving instance Ord (Record Solved)
deriving instance Show (Record Solved)
deriving instance Eq (Record Generalised)
deriving instance Ord (Record Generalised)
deriving instance Show (Record Generalised)
deriving instance Eq (Record Resolved)
deriving instance Ord (Record Resolved)
deriving instance Show (Record Resolved)

deriving instance Show (Prop Parsed)
deriving instance Eq (Prop Parsed)
deriving instance Ord (Prop Parsed)
deriving instance Show (Prop Renamed)
deriving instance Eq (Prop Renamed)
deriving instance Ord (Prop Renamed)
deriving instance Eq (Prop Generated)
deriving instance Ord (Prop Generated)
deriving instance Show (Prop Generated)
deriving instance Eq (Prop Solved)
deriving instance Ord (Prop Solved)
deriving instance Show (Prop Solved)
deriving instance Eq (Prop Generalised)
deriving instance Ord (Prop Generalised)
deriving instance Show (Prop Generalised)
deriving instance Eq (Prop Resolved)
deriving instance Ord (Prop Resolved)
deriving instance Show (Prop Resolved)

deriving instance Show (Array Parsed)
deriving instance Eq (Array Parsed)
deriving instance Ord (Array Parsed)
deriving instance Show (Array Renamed)
deriving instance Eq (Array Renamed)
deriving instance Ord (Array Renamed)
deriving instance Eq (Array Generated)
deriving instance Ord (Array Generated)
deriving instance Show (Array Generated)
deriving instance Eq (Array Solved)
deriving instance Ord (Array Solved)
deriving instance Show (Array Solved)
deriving instance Eq (Array Generalised)
deriving instance Ord (Array Generalised)
deriving instance Show (Array Generalised)
deriving instance Eq (Array Resolved)
deriving instance Ord (Array Resolved)
deriving instance Show (Array Resolved)

deriving instance Show (FieldE Parsed)
deriving instance Eq (FieldE Parsed)
deriving instance Ord (FieldE Parsed)
deriving instance Show (FieldE Renamed)
deriving instance Eq (FieldE Renamed)
deriving instance Ord (FieldE Renamed)
deriving instance Eq (FieldE Generated)
deriving instance Ord (FieldE Generated)
deriving instance Show (FieldE Generated)
deriving instance Eq (FieldE Solved)
deriving instance Ord (FieldE Solved)
deriving instance Show (FieldE Solved)
deriving instance Eq (FieldE Generalised)
deriving instance Ord (FieldE Generalised)
deriving instance Show (FieldE Generalised)
deriving instance Eq (FieldE Resolved)
deriving instance Ord (FieldE Resolved)
deriving instance Show (FieldE Resolved)

deriving instance Show (Literal Parsed)
deriving instance Eq (Literal Parsed)
deriving instance Ord (Literal Parsed)
deriving instance Show (Literal Renamed)
deriving instance Eq (Literal Renamed)
deriving instance Ord (Literal Renamed)
deriving instance Eq (Literal Generated)
deriving instance Ord (Literal Generated)
deriving instance Show (Literal Generated)
deriving instance Eq (Literal Solved)
deriving instance Ord (Literal Solved)
deriving instance Show (Literal Solved)
deriving instance Eq (Literal Generalised)
deriving instance Ord (Literal Generalised)
deriving instance Show (Literal Generalised)
deriving instance Eq (Literal Resolved)
deriving instance Ord (Literal Resolved)
deriving instance Show (Literal Resolved)

deriving instance Show (Number Parsed)
deriving instance Eq (Number Parsed)
deriving instance Ord (Number Parsed)
deriving instance Show (Number Renamed)
deriving instance Eq (Number Renamed)
deriving instance Ord (Number Renamed)
deriving instance Eq (Number Generated)
deriving instance Ord (Number Generated)
deriving instance Show (Number Generated)
deriving instance Eq (Number Solved)
deriving instance Ord (Number Solved)
deriving instance Show (Number Solved)
deriving instance Eq (Number Generalised)
deriving instance Ord (Number Generalised)
deriving instance Show (Number Generalised)
deriving instance Eq (Number Resolved)
deriving instance Ord (Number Resolved)
deriving instance Show (Number Resolved)

deriving instance Show (Lambda Parsed)
deriving instance Eq (Lambda Parsed)
deriving instance Ord (Lambda Parsed)
deriving instance Show (Lambda Renamed)
deriving instance Eq (Lambda Renamed)
deriving instance Ord (Lambda Renamed)
deriving instance Eq (Lambda Generated)
deriving instance Ord (Lambda Generated)
deriving instance Show (Lambda Generated)
deriving instance Eq (Lambda Solved)
deriving instance Ord (Lambda Solved)
deriving instance Show (Lambda Solved)
deriving instance Eq (Lambda Generalised)
deriving instance Ord (Lambda Generalised)
deriving instance Show (Lambda Generalised)
deriving instance Eq (Lambda Resolved)
deriving instance Ord (Lambda Resolved)
deriving instance Show (Lambda Resolved)

deriving instance Show (Infix Parsed)
deriving instance Eq (Infix Parsed)
deriving instance Ord (Infix Parsed)
deriving instance Show (Infix Renamed)
deriving instance Eq (Infix Renamed)
deriving instance Ord (Infix Renamed)
deriving instance Eq (Infix Generated)
deriving instance Ord (Infix Generated)
deriving instance Show (Infix Generated)
deriving instance Eq (Infix Solved)
deriving instance Ord (Infix Solved)
deriving instance Show (Infix Solved)
deriving instance Eq (Infix Generalised)
deriving instance Ord (Infix Generalised)
deriving instance Show (Infix Generalised)
deriving instance Eq (Infix Resolved)
deriving instance Ord (Infix Resolved)
deriving instance Show (Infix Resolved)

deriving instance Show (Let Parsed)
deriving instance Eq (Let Parsed)
deriving instance Ord (Let Parsed)
deriving instance Show (Let Renamed)
deriving instance Eq (Let Renamed)
deriving instance Ord (Let Renamed)
deriving instance Eq (Let Generated)
deriving instance Ord (Let Generated)
deriving instance Show (Let Generated)
deriving instance Eq (Let Solved)
deriving instance Ord (Let Solved)
deriving instance Show (Let Solved)
deriving instance Eq (Let Generalised)
deriving instance Ord (Let Generalised)
deriving instance Show (Let Generalised)
deriving instance Eq (Let Resolved)
deriving instance Ord (Let Resolved)
deriving instance Show (Let Resolved)

deriving instance Show (Bind Parsed)
deriving instance Eq (Bind Parsed)
deriving instance Ord (Bind Parsed)
deriving instance Show (Bind Renamed)
deriving instance Eq (Bind Renamed)
deriving instance Ord (Bind Renamed)
deriving instance Eq (Bind Generated)
deriving instance Ord (Bind Generated)
deriving instance Show (Bind Generated)
deriving instance Eq (Bind Solved)
deriving instance Ord (Bind Solved)
deriving instance Show (Bind Solved)
deriving instance Eq (Bind Generalised)
deriving instance Ord (Bind Generalised)
deriving instance Show (Bind Generalised)
deriving instance Eq (Bind Resolved)
deriving instance Ord (Bind Resolved)
deriving instance Show (Bind Resolved)

deriving instance Show (Param Parsed)
deriving instance Eq (Param Parsed)
deriving instance Ord (Param Parsed)
deriving instance Show (Param Renamed)
deriving instance Eq (Param Renamed)
deriving instance Ord (Param Renamed)
deriving instance Eq (Param Generated)
deriving instance Ord (Param Generated)
deriving instance Show (Param Generated)
deriving instance Eq (Param Solved)
deriving instance Ord (Param Solved)
deriving instance Show (Param Solved)
deriving instance Eq (Param Generalised)
deriving instance Ord (Param Generalised)
deriving instance Show (Param Generalised)
deriving instance Eq (Param Resolved)
deriving instance Ord (Param Resolved)
deriving instance Show (Param Resolved)

deriving instance Show (Variable Parsed)
deriving instance Eq (Variable Parsed)
deriving instance Ord (Variable Parsed)
deriving instance Show (Variable Renamed)
deriving instance Eq (Variable Renamed)
deriving instance Ord (Variable Renamed)
deriving instance Show (Variable Filled)
deriving instance Eq (Variable Filled)
deriving instance Ord (Variable Filled)
deriving instance Eq (Variable Generated)
deriving instance Ord (Variable Generated)
deriving instance Show (Variable Generated)
deriving instance Eq (Variable Solved)
deriving instance Ord (Variable Solved)
deriving instance Show (Variable Solved)
deriving instance Eq (Variable Generalised)
deriving instance Ord (Variable Generalised)
deriving instance Show (Variable Generalised)
deriving instance Eq (Variable Resolved)
deriving instance Ord (Variable Resolved)
deriving instance Show (Variable Resolved)

deriving instance Show (Global Parsed)
deriving instance Eq (Global Parsed)
deriving instance Ord (Global Parsed)
deriving instance Show (Global Renamed)
deriving instance Eq (Global Renamed)
deriving instance Ord (Global Renamed)
deriving instance Eq (Global Generated)
deriving instance Ord (Global Generated)
deriving instance Show (Global Generated)
deriving instance Eq (Global Solved)
deriving instance Ord (Global Solved)
deriving instance Show (Global Solved)
deriving instance Eq (Global Generalised)
deriving instance Ord (Global Generalised)
deriving instance Show (Global Generalised)
deriving instance Eq (Global Resolved)
deriving instance Ord (Global Resolved)
deriving instance Show (Global Resolved)

deriving instance Show (Apply Parsed)
deriving instance Eq (Apply Parsed)
deriving instance Ord (Apply Parsed)
deriving instance Show (Apply Renamed)
deriving instance Eq (Apply Renamed)
deriving instance Ord (Apply Renamed)
deriving instance Eq (Apply Generated)
deriving instance Ord (Apply Generated)
deriving instance Show (Apply Generated)
deriving instance Eq (Apply Solved)
deriving instance Ord (Apply Solved)
deriving instance Show (Apply Solved)
deriving instance Eq (Apply Generalised)
deriving instance Ord (Apply Generalised)
deriving instance Show (Apply Generalised)
deriving instance Eq (Apply Resolved)
deriving instance Ord (Apply Resolved)
deriving instance Show (Apply Resolved)

-------------------------------------------------------------------------------
-- Type system types

deriving instance Eq (Scheme Generated)
deriving instance Ord (Scheme Generated)
deriving instance Show (Scheme Generated)
deriving instance Eq (Scheme Solved)
deriving instance Ord (Scheme Solved)
deriving instance Show (Scheme Solved)
deriving instance Eq (Scheme Generalised)
deriving instance Ord (Scheme Generalised)
deriving instance Show (Scheme Generalised)
deriving instance Eq (Scheme Polymorphic)
deriving instance Ord (Scheme Polymorphic)
deriving instance Show (Scheme Polymorphic)

deriving instance Show EqualityConstraint
deriving instance Eq EqualityConstraint
deriving instance Ord EqualityConstraint

deriving instance Eq (Type Parsed)
deriving instance Ord (Type Parsed)
deriving instance Show (Type Parsed)
deriving instance Eq (Type Renamed)
deriving instance Ord (Type Renamed)
deriving instance Show (Type Renamed)
deriving instance Eq (Type Generated)
deriving instance Ord (Type Generated)
deriving instance Show (Type Generated)
deriving instance Eq (Type Solved)
deriving instance Ord (Type Solved)
deriving instance Show (Type Solved)
deriving instance Eq (Type Generalised)
deriving instance Ord (Type Generalised)
deriving instance Show (Type Generalised)
deriving instance Eq (Type Polymorphic)
deriving instance Ord (Type Polymorphic)
deriving instance Show (Type Polymorphic)

deriving instance Eq (TypeVariable Generated)
deriving instance Ord (TypeVariable Generated)
deriving instance Show (TypeVariable Generated)
deriving instance Eq (TypeVariable Parsed)
deriving instance Ord (TypeVariable Parsed)
deriving instance Show (TypeVariable Parsed)
deriving instance Eq (TypeVariable Renamed)
deriving instance Ord (TypeVariable Renamed)
deriving instance Show (TypeVariable Renamed)
deriving instance Eq (TypeVariable Solved)
deriving instance Ord (TypeVariable Solved)
deriving instance Show (TypeVariable Solved)
deriving instance Eq (TypeVariable Generalised)
deriving instance Ord (TypeVariable Generalised)
deriving instance Show (TypeVariable Generalised)
deriving instance Eq (TypeVariable Polymorphic)
deriving instance Ord (TypeVariable Polymorphic)
deriving instance Show (TypeVariable Polymorphic)

deriving instance Eq (TypeApplication Generated)
deriving instance Ord (TypeApplication Generated)
deriving instance Show (TypeApplication Generated)
deriving instance Eq (TypeApplication Parsed)
deriving instance Ord (TypeApplication Parsed)
deriving instance Show (TypeApplication Parsed)
deriving instance Eq (TypeApplication Renamed)
deriving instance Ord (TypeApplication Renamed)
deriving instance Show (TypeApplication Renamed)
deriving instance Eq (TypeApplication Solved)
deriving instance Ord (TypeApplication Solved)
deriving instance Show (TypeApplication Solved)
deriving instance Eq (TypeApplication Generalised)
deriving instance Ord (TypeApplication Generalised)
deriving instance Show (TypeApplication Generalised)
deriving instance Eq (TypeApplication Polymorphic)
deriving instance Ord (TypeApplication Polymorphic)
deriving instance Show (TypeApplication Polymorphic)

deriving instance Eq (TypeConstant Generated)
deriving instance Ord (TypeConstant Generated)
deriving instance Show (TypeConstant Generated)
deriving instance Eq (TypeConstant Parsed)
deriving instance Ord (TypeConstant Parsed)
deriving instance Show (TypeConstant Parsed)
deriving instance Eq (TypeConstant Renamed)
deriving instance Ord (TypeConstant Renamed)
deriving instance Show (TypeConstant Renamed)
deriving instance Eq (TypeConstant Solved)
deriving instance Ord (TypeConstant Solved)
deriving instance Show (TypeConstant Solved)
deriving instance Eq (TypeConstant Generalised)
deriving instance Ord (TypeConstant Generalised)
deriving instance Show (TypeConstant Generalised)
deriving instance Eq (TypeConstant Polymorphic)
deriving instance Ord (TypeConstant Polymorphic)
deriving instance Show (TypeConstant Polymorphic)

deriving instance Eq (TypeRow Generated)
deriving instance Ord (TypeRow Generated)
deriving instance Show (TypeRow Generated)
deriving instance Eq (TypeRow Parsed)
deriving instance Ord (TypeRow Parsed)
deriving instance Show (TypeRow Parsed)
deriving instance Eq (TypeRow Renamed)
deriving instance Ord (TypeRow Renamed)
deriving instance Show (TypeRow Renamed)
deriving instance Eq (TypeRow Solved)
deriving instance Ord (TypeRow Solved)
deriving instance Show (TypeRow Solved)
deriving instance Eq (TypeRow Generalised)
deriving instance Ord (TypeRow Generalised)
deriving instance Show (TypeRow Generalised)
deriving instance Eq (TypeRow Polymorphic)
deriving instance Ord (TypeRow Polymorphic)
deriving instance Show (TypeRow Polymorphic)

deriving instance Eq (Field Generated)
deriving instance Ord (Field Generated)
deriving instance Show (Field Generated)
deriving instance Eq (Field Parsed)
deriving instance Ord (Field Parsed)
deriving instance Show (Field Parsed)
deriving instance Eq (Field Renamed)
deriving instance Ord (Field Renamed)
deriving instance Show (Field Renamed)
deriving instance Eq (Field Solved)
deriving instance Ord (Field Solved)
deriving instance Show (Field Solved)
deriving instance Eq (Field Generalised)
deriving instance Ord (Field Generalised)
deriving instance Show (Field Generalised)
deriving instance Eq (Field Polymorphic)
deriving instance Ord (Field Polymorphic)
deriving instance Show (Field Polymorphic)

deriving instance Eq (ClassConstraint Generated)
deriving instance Ord (ClassConstraint Generated)
deriving instance Show (ClassConstraint Generated)
deriving instance Eq (ClassConstraint Solved)
deriving instance Ord (ClassConstraint Solved)
deriving instance Show (ClassConstraint Solved)
deriving instance Eq (ClassConstraint Generalised)
deriving instance Ord (ClassConstraint Generalised)
deriving instance Show (ClassConstraint Generalised)
deriving instance Eq (ClassConstraint Polymorphic)
deriving instance Ord (ClassConstraint Polymorphic)
deriving instance Show (ClassConstraint Polymorphic)

deriving instance Show (StagedScheme Parsed)
deriving instance Eq (StagedScheme Parsed)
deriving instance Ord (StagedScheme Parsed)
deriving instance Show (StagedScheme Renamed)
deriving instance Eq (StagedScheme Renamed)
deriving instance Ord (StagedScheme Renamed)
deriving instance Show (StagedScheme Solved)
deriving instance Eq (StagedScheme Solved)
deriving instance Ord (StagedScheme Solved)
deriving instance Show (StagedScheme Generalised)
deriving instance Eq (StagedScheme Generalised)
deriving instance Ord (StagedScheme Generalised)
deriving instance Show (StagedScheme Generated)
deriving instance Eq (StagedScheme Generated)
deriving instance Ord (StagedScheme Generated)
deriving instance Show (StagedScheme Resolved)
deriving instance Eq (StagedScheme Resolved)
deriving instance Ord (StagedScheme Resolved)

deriving instance Show (GlobalRef Parsed)
deriving instance Eq (GlobalRef Parsed)
deriving instance Ord (GlobalRef Parsed)
deriving instance Show (GlobalRef Renamed)
deriving instance Eq (GlobalRef Renamed)
deriving instance Ord (GlobalRef Renamed)
deriving instance Show (GlobalRef Solved)
deriving instance Eq (GlobalRef Solved)
deriving instance Ord (GlobalRef Solved)
deriving instance Show (GlobalRef Generalised)
deriving instance Eq (GlobalRef Generalised)
deriving instance Ord (GlobalRef Generalised)
deriving instance Show (GlobalRef Generated)
deriving instance Eq (GlobalRef Generated)
deriving instance Ord (GlobalRef Generated)
deriving instance Show (GlobalRef Resolved)
deriving instance Eq (GlobalRef Resolved)
deriving instance Ord (GlobalRef Resolved)

deriving instance Show (Binding Parsed)
deriving instance Eq (Binding Parsed)
deriving instance Ord (Binding Parsed)
deriving instance Show (Binding Renamed)
deriving instance Eq (Binding Renamed)
deriving instance Ord (Binding Renamed)
deriving instance Show (Binding Solved)
deriving instance Eq (Binding Solved)
deriving instance Ord (Binding Solved)
deriving instance Show (Binding Generalised)
deriving instance Eq (Binding Generalised)
deriving instance Ord (Binding Generalised)
deriving instance Show (Binding Generated)
deriving instance Eq (Binding Generated)
deriving instance Ord (Binding Generated)
deriving instance Show (Binding Resolved)
deriving instance Eq (Binding Resolved)
deriving instance Ord (Binding Resolved)

deriving instance Eq Cell
deriving instance Ord Cell
deriving instance Show Cell

deriving instance Eq IncompleteGlobalRef
deriving instance Ord IncompleteGlobalRef
deriving instance Show IncompleteGlobalRef

deriving instance Eq (Default Polymorphic)
deriving instance Ord (Default Polymorphic)
deriving instance Show (Default Polymorphic)
