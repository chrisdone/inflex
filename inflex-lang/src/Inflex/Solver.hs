{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE DeriveFunctor #-}
-- |

module Inflex.Solver where

import Control.Monad
import Data.Bifunctor
import Data.List
import Data.List.NonEmpty (NonEmpty(..))
import Data.Map.Strict (Map)
import Data.Sequence (Seq)
import Data.Text (Text)
import Inflex.Generator
import Inflex.Optics
import Inflex.Types
import Optics

--------------------------------------------------------------------------------
-- Solver types

data SolveError
  = ConstantMismatch
  | OccursCheckFail
  | TypeMismatch EqualityConstraint
  deriving (Show, Eq)

data ParseSolveError
  = SolverErrors (NonEmpty SolveError)
  | GeneratorErrored RenameGenerateError
  deriving (Show, Eq)

data IsSolved a = IsSolved
  { thing :: !a
  , mappings :: !(Map Cursor SourceLocation)
  , classes :: !(Seq (ClassConstraint Generated))
  } deriving (Show, Eq)

data Substitution = Substitution
  { before :: !(TypeVariable Generated)
  , after :: !(Type Generated)
  } deriving (Show, Eq)

$(makeLensesWith
    (inflexRules ['before, 'after])
    ''Substitution)

--------------------------------------------------------------------------------
-- Top-level

solveText ::
     FilePath
  -> Text
  -> Either ParseSolveError (IsSolved (Expression Solved))
solveText fp text = do
  HasConstraints {thing = _expression, mappings, classes} <-
    first GeneratorErrored (generateText fp text)
  first
    SolverErrors
    (let thing = undefined
      in pure (IsSolved {thing, mappings, classes}))

--------------------------------------------------------------------------------
-- Unification

unifyConstraints ::
     Seq EqualityConstraint -> Either (NonEmpty SolveError) (Seq Substitution)
unifyConstraints =
  foldM
    (\constraints equalityConstraint ->
       unifyEqualityConstraint
         (substituteEqualityConstraint constraints equalityConstraint))
    mempty

unifyEqualityConstraint :: EqualityConstraint -> Either (NonEmpty SolveError) (Seq Substitution)
unifyEqualityConstraint equalityConstraint@EqualityConstraint {type1, type2} =
  case (type1, type2) of
    (ApplyType typeApplication1, ApplyType typeApplication2) ->
      unifyTypeApplications typeApplication1 typeApplication2
    (VariableType typeVariable, typ) -> bindTypeVariable typeVariable typ
    (typ, VariableType typeVariable) -> bindTypeVariable typeVariable typ
    (ConstantType typeConstant1, ConstantType typeConstant2)
      | typeConstant1 == typeConstant2 -> pure mempty
    _ -> Left (pure (TypeMismatch equalityConstraint))

unifyTypeApplications ::
     TypeApplication Generated
  -> TypeApplication Generated
  -> Either (NonEmpty SolveError) (Seq Substitution)
unifyTypeApplications typeApplication1 typeApplication2 = do
  existing <-
    unifyEqualityConstraint
      EqualityConstraint {type1 = function1, type2 = function2, location}
  new <-
    unifyEqualityConstraint
      (substituteEqualityConstraint
         existing
         (EqualityConstraint {type1 = argument1, type2 = argument2, location}))
  pure (extendSubstitutions Extension {existing, new})
  where
    TypeApplication {function = function1, argument = argument1, location} {-TODO: set location properly -}
     = typeApplication1
    TypeApplication {function = function2, argument = argument2} =
      typeApplication2

--------------------------------------------------------------------------------
-- Binding

bindTypeVariable :: TypeVariable Generated -> Type Generated -> Either (NonEmpty SolveError) (Seq Substitution)
bindTypeVariable typeVariable typ
  | typ == VariableType typeVariable = pure mempty
  -- TODO: Occurs check.
  -- | occursCheck = Left OccursCheckFail
  | otherwise = pure (pure Substitution {before = typeVariable, after = typ})

--------------------------------------------------------------------------------
-- Extension

data Extension = Extension
  { existing :: Seq Substitution
  , new :: Seq Substitution
  }

extendSubstitutions :: Extension -> Seq Substitution
extendSubstitutions Extension {new, existing} = existing' <> new
  where
    existing' = fmap (over substitutionAfterL (substituteType new)) existing

--------------------------------------------------------------------------------
-- Substitution

substituteEqualityConstraint ::
     Seq Substitution -> EqualityConstraint -> EqualityConstraint
substituteEqualityConstraint substitutions equalityConstraint =
  EqualityConstraint
    { type1 = substituteType substitutions type1
    , type2 = substituteType substitutions type2
    , ..
    }
  where
    EqualityConstraint {type1, type2, ..} = equalityConstraint

substituteType :: Seq Substitution -> Type Generated -> Type Generated
substituteType substitutions = go
  where
    go =
      \case
        typ@ConstantType {} -> typ
        ApplyType TypeApplication {function, argument, ..} ->
          ApplyType
            TypeApplication {function = go function, argument = go argument, ..}
        typ@(VariableType typeVariable :: Type Generated) ->
          case find
                 (\Substitution {before} -> before == typeVariable)
                 substitutions of
            Just Substitution {after} -> after
            Nothing -> typ
