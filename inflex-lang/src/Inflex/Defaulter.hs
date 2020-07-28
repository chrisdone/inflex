{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE DuplicateRecordFields #-}

-- | Defaulting class instances that are ambiguous.

module Inflex.Defaulter where

import           Data.Bifunctor
import           Data.Foldable
import           Data.List
import           Data.List.NonEmpty (NonEmpty(..))
import           Data.Map.Strict (Map)
import           Data.Maybe
import           Data.Ord
import           Data.Set (Set)
import qualified Data.Set as Set
import           Data.Text (Text)
import           Inflex.Resolver
import           Inflex.Types
import           Numeric.Natural

--------------------------------------------------------------------------------
-- Types

data DefaulterError
  = ResolutionError ResolutionError
  | DefaultingNoInstanceFound (ClassConstraint Polymorphic)
  deriving (Eq, Show)

data ResolverDefaulterError
  = DefaulterError DefaulterError
  | GeneraliseResolverError GeneraliseResolveError
  deriving (Eq, Show)

--------------------------------------------------------------------------------
-- Top-level entry points

defaultText :: Map Hash (Scheme Polymorphic) -> FilePath -> Text -> Either ResolverDefaulterError Cell
defaultText globals fp text = do
  resolved <- first GeneraliseResolverError (resolveText globals fp text)
  first DefaulterError (defaultResolvedExpression resolved)

defaultResolvedExpression ::
     IsResolved (Expression Resolved) -> Either DefaulterError Cell
defaultResolvedExpression IsResolved {scheme = scheme@Scheme {constraints}} =
  pure
    Cell
      { location = undefined
      , scheme = undefined
      , defaultedClassConstraints = undefined
      , ambiguousClassConstraints = undefined
      , expression = undefined
      }
  where
    constrainedDefaultableTypeVariables :: Set (TypeVariable Polymorphic)
    constrainedDefaultableTypeVariables =
      Set.intersection
        (constraintedTypeVariables scheme)
        (defaultableTypeVariables scheme)

--------------------------------------------------------------------------------
-- Applying defaults

-- | Traverse down the expression for each class constraint, and if
-- there is a default for that class constraint, apply a dictionary
-- argument to the lambda. If there's no default for that class
-- constraint, we step down into the lambda and continue.
applyDefaults ::
     [ClassConstraint Polymorphic]
  -> Set (Default Polymorphic)
  -> Expression Resolved
  -> Expression Resolved
applyDefaults = undefined

--------------------------------------------------------------------------------
-- Generating a default from a class constraint

-- Uses Inflex.Resolver.resolveConstraint to check that the suggested
-- types correctly produce an instance for the class constraint.
--
-- If it produces a ResolutionError, that's a hard fail. If no instance
-- is found, that's a hard fail.

-- | We check to see whether the defaulted class constraint is valid.
makeValidDefault ::
     ClassConstraint Polymorphic
  -> ClassConstraint Polymorphic
  -> Either DefaulterError (Default Polymorphic)
makeValidDefault classConstraintOriginal classConstraintDefaulted = do
  resolutionSuccess <-
    first ResolutionError (resolvePolyConstraint classConstraintDefaulted)
  case resolutionSuccess of
    InstanceFound instanceName ->
      pure
        Default
          {classConstraintOriginal, classConstraintDefaulted, instanceName}
    NoInstanceButPoly noInstanceConstraint ->
      Left (DefaultingNoInstanceFound noInstanceConstraint)

--------------------------------------------------------------------------------
-- Infer an appropriate defaulted type for a set of constraints

-- | Given a set of constraints mentioning the given type variable,
-- produce an appropriate constant.
--
-- It's not the responsibility of this function to determine validity
-- of instances. Just to produce a type @Integer@ or @Decimal n@.
--
-- Order of priority: FromDecimal x > FromDecimal y > FromInteger,
-- such that x > y.
suggestTypeConstant ::
     NonEmpty (ClassConstraint Polymorphic)
  -> Either DefaulterError (Maybe (Type Polymorphic))
suggestTypeConstant =
  fmap (listToMaybe . map snd . sortBy (flip (comparing fst)) . catMaybes) .
  traverse suggestedConstant . toList
  where
    suggestedConstant ::
         ClassConstraint Polymorphic
      -> Either DefaulterError (Maybe (Natural, Type Polymorphic))
    suggestedConstant =
      \case
        ClassConstraint {className = FromIntegerClassName} ->
          pure
            (pure
               ( 0
               , ConstantType
                   TypeConstant
                     {location = DefaultedCursor, name = IntegerTypeName}))
        ClassConstraint {className = FromDecimalClassName, typ = params} ->
          case params of
            ConstantType argument@TypeConstant {name = NatTypeName places} :| [_] ->
              pure
                (pure
                   ( places
                   , ApplyType
                       TypeApplication
                         { location = DefaultedCursor
                         , kind = TypeKind
                         , function =
                             ConstantType
                               TypeConstant
                                 { location = DefaultedCursor
                                 , name = DecimalTypeName
                                 }
                         , argument = ConstantType argument
                         }))
            _ -> pure Nothing
        _ -> pure Nothing

--------------------------------------------------------------------------------
-- Type variables mentioned in the class constraints

-- | Obtain the type variables mentioned in class constraints.
--
-- Example:
--
-- f(C a => C b => a -> b -> c) => {a,b}
constraintedTypeVariables :: Scheme Polymorphic -> Set (TypeVariable Polymorphic)
constraintedTypeVariables Scheme {constraints} =
  foldMap (\ClassConstraint {typ} -> foldMap typeVariables typ) constraints
  where
    typeVariables =
      \case
        VariableType typeVariable -> Set.singleton typeVariable
        ApplyType TypeApplication {function, argument} ->
          typeVariables function <> typeVariables argument
        ConstantType {} -> mempty

--------------------------------------------------------------------------------
-- Find type variables which can be defaulted

-- | Produce the unique set of variables that may meaningfully be
-- defaulted for a cell.
--
-- I'm 90% sure that this is the right way to attack the problem of
-- defaulting cells. But I don't know of a precedent in the
-- literature/implementation world.
--
-- Examples:
--
-- (FromInteger a, FromDecimal b) => (a -> b) => {}
-- (FromInteger a, FromDecimal b) => {x: a, y: b} => {a,b}
-- (FromInteger a, FromDecimal b, FromDecimal c) => {x: a, y: c -> b} => {a,b}
-- (FromDecimal b, FromDecimal c) => {x: c, y: c -> b} => {b,c}
--
defaultableTypeVariables :: Scheme Polymorphic -> Set (TypeVariable Polymorphic)
defaultableTypeVariables Scheme {typ} = typeVariables typ
  where
    typeVariables =
      \case
        VariableType typeVariable -> Set.singleton typeVariable
        ApplyType TypeApplication {function, argument} ->
          case function of
            ConstantType TypeConstant {name = FunctionTypeName} ->
              mempty -- We ignore `argument', the left-hand-side
                     -- negative-position (the input type). We can't
                     -- necessarily default any type variable that is in
                     -- negative position.
            _ -> typeVariables function <> typeVariables argument
        ConstantType {} -> mempty
