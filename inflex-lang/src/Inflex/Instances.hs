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

deriving instance Show (Literal Parsed)
deriving instance Eq (Literal Parsed)
deriving instance Ord (Literal Parsed)
deriving instance Show (Literal Renamed)
deriving instance Eq (Literal Renamed)
deriving instance Ord (Literal Renamed)
deriving instance Eq (Literal Generated)
deriving instance Ord (Literal Generated)
deriving instance Show (Literal Generated)

deriving instance Show (Integery Parsed)
deriving instance Eq (Integery Parsed)
deriving instance Ord (Integery Parsed)
deriving instance Show (Integery Renamed)
deriving instance Eq (Integery Renamed)
deriving instance Ord (Integery Renamed)
deriving instance Eq (Integery Generated)
deriving instance Ord (Integery Generated)
deriving instance Show (Integery Generated)

deriving instance Show (Lambda Parsed)
deriving instance Eq (Lambda Parsed)
deriving instance Ord (Lambda Parsed)
deriving instance Show (Lambda Renamed)
deriving instance Eq (Lambda Renamed)
deriving instance Ord (Lambda Renamed)
deriving instance Eq (Lambda Generated)
deriving instance Ord (Lambda Generated)
deriving instance Show (Lambda Generated)

deriving instance Show (Param Parsed)
deriving instance Eq (Param Parsed)
deriving instance Ord (Param Parsed)
deriving instance Show (Param Renamed)
deriving instance Eq (Param Renamed)
deriving instance Ord (Param Renamed)
deriving instance Eq (Param Generated)
deriving instance Ord (Param Generated)
deriving instance Show (Param Generated)

-------------------------------------------------------------------------------
-- Type system types

deriving instance Eq (Type Generated)
deriving instance Ord (Type Generated)
deriving instance Show (Type Generated)

deriving instance Eq (TypeApplication Generated)
deriving instance Ord (TypeApplication Generated)
deriving instance Show (TypeApplication Generated)

deriving instance Eq (TypeConstant Generated)
deriving instance Ord (TypeConstant Generated)
deriving instance Show (TypeConstant Generated)

deriving instance Eq (ClassConstraint Generated)
deriving instance Ord (ClassConstraint Generated)
deriving instance Show (ClassConstraint Generated)
